-- Crash reports from the app, read in the Supabase dashboard.
--
-- Kept in this project rather than sent to a crash-reporting service, so no
-- one else receives them. Deliberately not linked to an account: there is
-- no user_id, and the app sends nothing personal — the error, where in the
-- code it happened, and the app and OS versions.
--
-- Clients may insert and nothing else: no select, update or delete policy
-- exists, so a report cannot be read back through the API by anyone but the
-- service role. The length checks bound what one insert can store, since
-- the publishable key that allows the insert is in every copy of the app.
create table public.crash_reports (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  app_version text not null check (length(app_version) <= 40),
  os text not null check (length(os) <= 200),
  fatal boolean not null default false,
  error text not null check (length(error) <= 2000),
  stack text not null default '' check (length(stack) <= 8000)
);

alter table public.crash_reports enable row level security;

-- Reports can come from the login screen too, before anyone is signed in.
create policy "anyone can file a crash report" on public.crash_reports
  for insert to anon, authenticated
  with check (true);
