-- Notifications for shared lists: "Ben added Milk" on the phones of the
-- other members, when the app is closed.
--
-- Three parts. Phones register the token Firebase gives them. Triggers on
-- the shared tables note who changed what, one row per list and person, so
-- twenty ticks are one entry. And once a minute a job hands entries that
-- have gone quiet to the send-list-notifications function, which turns
-- each into one message per recipient.

create extension if not exists pg_net;

-- A phone that can be notified. Keyed by the token, because the token is
-- the phone: when someone else signs in on it, the row changes hands
-- instead of the previous owner still being notified there.
create table public.device_tokens (
  token text primary key check (length(token) between 20 and 4096),
  user_id uuid not null references auth.users (id) on delete cascade,
  lang text not null default 'en' check (lang in ('en', 'bg')),
  updated_at timestamptz not null default now()
);
create index device_tokens_user_idx on public.device_tokens (user_id);

-- No policies: tokens are written through the two functions below and read
-- only by the sending function, which uses the service role.
alter table public.device_tokens enable row level security;

create or replace function public.register_device(
  device_token text,
  device_lang text
)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into public.device_tokens (token, user_id, lang)
  values (
    device_token,
    (select auth.uid()),
    case when device_lang = 'bg' then 'bg' else 'en' end
  )
  on conflict (token) do update
    set user_id = excluded.user_id,
        lang = excluded.lang,
        updated_at = now();
$$;

create or replace function public.unregister_device(device_token text)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.device_tokens
  where token = device_token and user_id = (select auth.uid());
$$;

-- What one person has done to one list since the others were last told.
create table public.shared_list_activity (
  list_id uuid not null
    references public.shared_lists (id) on delete cascade,
  actor_id uuid not null,
  added integer not null default 0,
  -- The first few names, for "added Milk, Bread".
  added_names text[] not null default '{}',
  changed integer not null default 0,
  last_at timestamptz not null default now(),
  primary key (list_id, actor_id)
);
alter table public.shared_list_activity enable row level security;

-- When someone was last sent a "list updated" notice about a person, so a
-- partner ticking their way round a shop is one notice, not one a minute.
create table public.shared_list_notices (
  list_id uuid not null
    references public.shared_lists (id) on delete cascade,
  actor_id uuid not null,
  sent_at timestamptz not null default now(),
  primary key (list_id, actor_id)
);
alter table public.shared_list_notices enable row level security;

create or replace function public.note_list_activity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := (select auth.uid());
  is_add boolean;
begin
  if actor is null then
    return null;
  end if;
  -- Nobody else on the list, nobody to tell: a list being shared for the
  -- first time uploads everything before anyone has joined.
  if not exists (
    select 1 from public.shared_list_members m
    where m.list_id = new.list_id and m.user_id <> actor
  ) then
    return null;
  end if;

  is_add := tg_op = 'INSERT'
    and tg_table_name = 'shared_products'
    and new.deleted_at is null;

  insert into public.shared_list_activity as a
    (list_id, actor_id, added, added_names, changed, last_at)
  values (
    new.list_id,
    actor,
    case when is_add then 1 else 0 end,
    -- Through jsonb because only some of these tables have a name.
    case when is_add then array[to_jsonb(new) ->> 'name'] else '{}' end,
    case when is_add then 0 else 1 end,
    now()
  )
  on conflict (list_id, actor_id) do update
    set added = a.added + excluded.added,
        added_names = case
          when cardinality(a.added_names) < 3
            then a.added_names || excluded.added_names
          else a.added_names
        end,
        changed = a.changed + excluded.changed,
        last_at = now();
  return null;
end;
$$;

create trigger shared_products_activity after insert or update
  on public.shared_products for each row
  execute function public.note_list_activity();
create trigger shared_meals_activity after insert or update
  on public.shared_meals for each row
  execute function public.note_list_activity();
create trigger shared_meal_recipes_activity after insert or update
  on public.shared_meal_recipes for each row
  execute function public.note_list_activity();

-- Hands over the entries that have been quiet for 45 seconds, removing
-- them so that two overlapping runs cannot send the same one twice.
-- `notify` is false for an entry with nothing added when that person's
-- changes to that list were already announced within the hour.
create or replace function public.claim_list_activity()
returns table (
  list_id uuid,
  list_name text,
  actor_id uuid,
  actor_name text,
  added integer,
  added_names text[],
  changed integer,
  notify boolean
)
language plpgsql
security definer
set search_path = ''
as $$
-- The result columns share names with table columns; in the query below
-- a bare name means the column.
#variable_conflict use_column
begin
  return query
  with due as (
    delete from public.shared_list_activity a
    where a.last_at < now() - interval '45 seconds'
    returning a.*
  ),
  decided as (
    select
      d.*,
      d.added > 0 or not exists (
        select 1 from public.shared_list_notices n
        where n.list_id = d.list_id
          and n.actor_id = d.actor_id
          and n.sent_at > now() - interval '1 hour'
      ) as should_notify
    from due d
  ),
  -- Runs whether or not anything reads it: a statement that writes always
  -- does.
  logged as (
    insert into public.shared_list_notices (list_id, actor_id, sent_at)
    select x.list_id, x.actor_id, now() from decided x
    where x.should_notify and x.added = 0
    on conflict (list_id, actor_id) do update set sent_at = now()
    returning 1
  )
  select
    x.list_id,
    l.name,
    x.actor_id,
    coalesce(m.display_name, ''),
    x.added,
    x.added_names,
    x.changed,
    x.should_notify
  from decided x
  join public.shared_lists l on l.id = x.list_id
  left join public.shared_list_members m
    on m.list_id = x.list_id and m.user_id = x.actor_id;
end;
$$;

revoke execute on function public.register_device(text, text) from public, anon;
revoke execute on function public.unregister_device(text) from public, anon;
grant execute on function public.register_device(text, text) to authenticated;
grant execute on function public.unregister_device(text) to authenticated;
revoke execute on function public.note_list_activity()
  from public, anon, authenticated;
revoke execute on function public.claim_list_activity()
  from public, anon, authenticated;
grant execute on function public.claim_list_activity() to service_role;

-- Once a minute, and only when an entry has gone quiet, ask the function to
-- send. The key here is the publishable one, which is in every copy of the
-- app; the function takes no input and returns only counts.
select cron.schedule(
  'send-list-notifications',
  '* * * * *',
  $$
  select net.http_post(
    url := 'https://wqidsbhicyfufncxyqww.supabase.co/functions/v1/send-list-notifications',
    headers := jsonb_build_object(
      'Authorization', 'Bearer sb_publishable_oaYh7Ba38nsfR4GgU3OIxA_NNRpxgsZ',
      'apikey', 'sb_publishable_oaYh7Ba38nsfR4GgU3OIxA_NNRpxgsZ',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  )
  where exists (
    select 1 from public.shared_list_activity
    where last_at < now() - interval '45 seconds'
  )
  $$
);
