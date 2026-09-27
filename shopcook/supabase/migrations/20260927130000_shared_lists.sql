-- Shared lists.
--
-- Only lists someone chooses to share live here; everything else stays on
-- the phone. A shared list belongs to its members: whoever shared it, plus
-- anyone who joined with an invite code.
--
-- These tables take over from the 2026-09-15 mirror tables (shopping_lists,
-- meals, products, recipes), which no version of the app ever used and which
-- had fallen behind the app's schema. Those are left in place, empty.
--
-- Rows are never deleted by the app, only tombstoned (deleted_at), so a
-- phone that was offline still learns that a row went away. updated_at is
-- set by trigger, never trusted from a client, and is the cursor phones
-- pull changes from.

create table public.shared_lists (
  id uuid primary key,
  owner_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  name text not null check (length(name) <= 200),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.shared_list_members (
  list_id uuid not null
    references public.shared_lists (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (list_id, user_id)
);
create index shared_list_members_user_idx
  on public.shared_list_members (user_id);

create table public.shared_list_invites (
  code text primary key check (code ~ '^[A-Z2-9]{8}$'),
  list_id uuid not null
    references public.shared_lists (id) on delete cascade,
  created_by uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  expires_at timestamptz not null default now() + interval '7 days'
);
create index shared_list_invites_list_idx
  on public.shared_list_invites (list_id);

create table public.shared_meals (
  id uuid primary key,
  list_id uuid not null
    references public.shared_lists (id) on delete cascade,
  name text not null check (length(name) <= 200),
  planned_for date,
  cooked_at timestamptz,
  created_at timestamptz not null,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index shared_meals_list_updated_idx
  on public.shared_meals (list_id, updated_at);

-- No foreign key on meal_id: a phone pushes rows in whatever order they
-- changed, and an item can arrive a moment before its meal.
create table public.shared_products (
  id uuid primary key,
  list_id uuid not null
    references public.shared_lists (id) on delete cascade,
  meal_id uuid,
  name text not null check (length(name) <= 300),
  quantity text not null default '' check (length(quantity) <= 60),
  unit text not null default '' check (length(unit) <= 60),
  is_checked boolean not null default false,
  price double precision,
  category_override text check (length(category_override) <= 40),
  is_staple boolean not null default false,
  cleared_at timestamptz,
  created_at timestamptz not null,
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index shared_products_list_updated_idx
  on public.shared_products (list_id, updated_at);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger shared_lists_touch before insert or update
  on public.shared_lists for each row
  execute function public.touch_updated_at();
create trigger shared_meals_touch before insert or update
  on public.shared_meals for each row
  execute function public.touch_updated_at();
create trigger shared_products_touch before insert or update
  on public.shared_products for each row
  execute function public.touch_updated_at();

-- Membership check for the policies. Security definer so a policy on the
-- members table can call it without recursing into its own policy.
create or replace function public.is_list_member(target uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.shared_list_members
    where list_id = target and user_id = (select auth.uid())
  );
$$;

-- Whoever shares a list is its first member.
create or replace function public.add_list_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.shared_list_members (list_id, user_id)
  values (new.id, new.owner_id)
  on conflict do nothing;
  return new;
end;
$$;

create trigger shared_lists_add_owner after insert
  on public.shared_lists for each row
  execute function public.add_list_owner();

alter table public.shared_lists enable row level security;
alter table public.shared_list_members enable row level security;
alter table public.shared_list_invites enable row level security;
alter table public.shared_meals enable row level security;
alter table public.shared_products enable row level security;

create policy "members read lists" on public.shared_lists
  for select to authenticated
  using ((select public.is_list_member(id)));
create policy "anyone shares their own list" on public.shared_lists
  for insert to authenticated
  with check (owner_id = (select auth.uid()));
-- Members may rename a list and nothing else: the column grant below keeps
-- owner_id and deleted_at out of reach. Deleting for everyone goes through
-- delete_shared_list, which checks the caller is the owner.
create policy "members rename lists" on public.shared_lists
  for update to authenticated
  using ((select public.is_list_member(id)))
  with check ((select public.is_list_member(id)));
revoke update on public.shared_lists from authenticated;
grant update (name) on public.shared_lists to authenticated;

create policy "members see each other" on public.shared_list_members
  for select to authenticated
  using ((select public.is_list_member(list_id)));
create policy "members leave" on public.shared_list_members
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- Invites have no policies: they are only made and redeemed through the
-- functions below.

create policy "members read meals" on public.shared_meals
  for select to authenticated
  using ((select public.is_list_member(list_id)));
create policy "members add meals" on public.shared_meals
  for insert to authenticated
  with check ((select public.is_list_member(list_id)));
create policy "members change meals" on public.shared_meals
  for update to authenticated
  using ((select public.is_list_member(list_id)))
  with check ((select public.is_list_member(list_id)));

create policy "members read products" on public.shared_products
  for select to authenticated
  using ((select public.is_list_member(list_id)));
create policy "members add products" on public.shared_products
  for insert to authenticated
  with check ((select public.is_list_member(list_id)));
create policy "members change products" on public.shared_products
  for update to authenticated
  using ((select public.is_list_member(list_id)))
  with check ((select public.is_list_member(list_id)));

-- An invite code for a list the caller belongs to. Reuses one with at least
-- a day left, so sharing twice sends the same code.
create or replace function public.create_list_invite(target uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result text;
begin
  if not public.is_list_member(target) then
    raise exception 'not a member' using errcode = '42501';
  end if;

  select code into result from public.shared_list_invites
  where list_id = target and expires_at > now() + interval '1 day'
  order by expires_at desc limit 1;
  if result is not null then
    return result;
  end if;

  loop
    result := '';
    for i in 1..8 loop
      result := result || substr(
        alphabet,
        1 + floor(random() * length(alphabet))::int,
        1
      );
    end loop;
    begin
      insert into public.shared_list_invites (code, list_id)
      values (result, target);
      return result;
    exception when unique_violation then
      -- Taken; try another.
    end;
  end loop;
end;
$$;

-- Joins the list an invite code points at, and returns its id.
create or replace function public.join_list(invite text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  target uuid;
begin
  select i.list_id into target
  from public.shared_list_invites i
  join public.shared_lists l on l.id = i.list_id
  where i.code = upper(replace(trim(invite), '-', ''))
    and i.expires_at > now()
    and l.deleted_at is null;

  if target is null then
    raise exception 'invalid invite' using errcode = 'P0002';
  end if;

  insert into public.shared_list_members (list_id, user_id)
  values (target, (select auth.uid()))
  on conflict do nothing;
  return target;
end;
$$;

-- The owner stops sharing a list for every member. The rows stay as
-- tombstones so each phone learns of it on its next pull.
create or replace function public.delete_shared_list(target uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.shared_lists set deleted_at = now()
  where id = target and owner_id = (select auth.uid());
  if not found then
    raise exception 'not the owner' using errcode = '42501';
  end if;
  delete from public.shared_list_invites where list_id = target;
end;
$$;

revoke execute on function public.create_list_invite(uuid) from public, anon;
revoke execute on function public.join_list(text) from public, anon;
revoke execute on function public.delete_shared_list(uuid) from public, anon;
revoke execute on function public.is_list_member(uuid) from public, anon;
revoke execute on function public.add_list_owner()
  from public, anon, authenticated;
grant execute on function public.create_list_invite(uuid) to authenticated;
grant execute on function public.join_list(text) to authenticated;
grant execute on function public.delete_shared_list(uuid) to authenticated;
grant execute on function public.is_list_member(uuid) to authenticated;

-- Live updates, so a partner ticking milk off shows while you are in the
-- shop. Realtime applies the select policies above, so a phone only hears
-- about lists it belongs to.
alter publication supabase_realtime add table public.shared_lists;
alter publication supabase_realtime add table public.shared_meals;
alter publication supabase_realtime add table public.shared_products;

-- Revised the same day: stopping sharing removes the server copy outright
-- rather than tombstoning it. The cascade takes members, meals, items and
-- invites with it; each member's phone notices the list is gone on its next
-- pull and keeps its own copy as an ordinary list. The owner can share it
-- again later under the same id.
create or replace function public.delete_shared_list(target uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.shared_lists
  where id = target and owner_id = (select auth.uid());
  if not found then
    raise exception 'not the owner' using errcode = '42501';
  end if;
end;
$$;
