-- Server mirror of the on-device Drift schema, so a list can outlive one
-- phone. The app stays offline-first: Drift remains the source of reads and
-- these tables are what it reconciles against.
--
-- Two columns exist only for syncing:
--   updated_at  -- delta cursor; maintained by trigger, not trusted from the
--                  client, whose clock may be wrong or deliberately lying.
--   deleted_at  -- tombstone. A hard delete leaves no trace, so another
--                  device would never learn the row went away and would
--                  happily push it back.
--
-- user_id is denormalised onto every table rather than resolved through the
-- parent list. RLS runs per row, and an EXISTS subquery up the tree on every
-- read of every product is a cost paid forever to avoid one column.

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

-- Ids are generated on the device (uuid v4) so a row created offline keeps
-- its identity when it reaches the server; no server-side default.
create table public.shopping_lists (
  id uuid primary key,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.meals (
  id uuid primary key,
  list_id uuid not null
    references public.shopping_lists (id) on delete cascade,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  name text not null,
  planned_for date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.products (
  id uuid primary key,
  list_id uuid not null
    references public.shopping_lists (id) on delete cascade,
  meal_id uuid references public.meals (id) on delete cascade,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  name text not null,
  quantity text not null default '',
  unit text not null default '',
  is_checked boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table public.recipes (
  id uuid primary key,
  meal_id uuid not null references public.meals (id) on delete cascade,
  user_id uuid not null default auth.uid()
    references auth.users (id) on delete cascade,
  title text not null,
  source_url text not null,
  thumbnail_url text not null default '',
  -- Matches the RecipeSourceType enum names Drift writes.
  source_type text not null default 'web'
    check (source_type in ('web', 'video')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- (user_id, updated_at) is the pull query: "everything of mine that changed
-- since my last cursor". The parent-id indexes serve the cascades and joins.
create index shopping_lists_user_updated_idx
  on public.shopping_lists (user_id, updated_at desc);
create index meals_user_updated_idx
  on public.meals (user_id, updated_at desc);
create index meals_list_idx on public.meals (list_id);
create index products_user_updated_idx
  on public.products (user_id, updated_at desc);
create index products_list_idx on public.products (list_id);
create index products_meal_idx on public.products (meal_id);
create index recipes_user_updated_idx
  on public.recipes (user_id, updated_at desc);
create index recipes_meal_idx on public.recipes (meal_id);

create trigger shopping_lists_touch_updated_at
  before update on public.shopping_lists
  for each row execute function public.touch_updated_at();
create trigger meals_touch_updated_at
  before update on public.meals
  for each row execute function public.touch_updated_at();
create trigger products_touch_updated_at
  before update on public.products
  for each row execute function public.touch_updated_at();
create trigger recipes_touch_updated_at
  before update on public.recipes
  for each row execute function public.touch_updated_at();

alter table public.shopping_lists enable row level security;
alter table public.meals enable row level security;
alter table public.products enable row level security;
alter table public.recipes enable row level security;

-- `to authenticated` keeps the anon key out entirely; auth.uid() is wrapped
-- in a select so the planner evaluates it once per statement rather than
-- once per row.
create policy "own shopping lists" on public.shopping_lists
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "own meals" on public.meals
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "own products" on public.products
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

create policy "own recipes" on public.recipes
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
