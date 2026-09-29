-- Who changed what in a shared list.
--
-- Each shared row records who last changed it, stamped by the server from
-- the caller's token (a client cannot claim to be someone else), and each
-- member has a display name the others see instead of an email address.

alter table public.shared_meals
  add column updated_by uuid default auth.uid();
alter table public.shared_products
  add column updated_by uuid default auth.uid();

alter table public.shared_list_members
  add column display_name text not null default ''
    check (length(display_name) <= 40);

create or replace function public.touch_shared_row()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  new.updated_by = (select auth.uid());
  return new;
end;
$$;

create or replace trigger shared_meals_touch before insert or update
  on public.shared_meals for each row
  execute function public.touch_shared_row();
create or replace trigger shared_products_touch before insert or update
  on public.shared_products for each row
  execute function public.touch_shared_row();

-- Members set their own name and nothing else about their membership.
create policy "members name themselves" on public.shared_list_members
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
grant update (display_name) on public.shared_list_members to authenticated;
