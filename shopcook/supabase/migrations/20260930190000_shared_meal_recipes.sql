-- Recipes attached to the meals of a shared list.
--
-- A recipe is a link with a title and a picture, not the page itself: each
-- member's phone reads the page for itself when the recipe is opened. The
-- row is keyed by meal and link rather than by an id, because each member
-- keeps the recipe in their own library under their own id — the link is
-- what the two libraries have in common.
create table public.shared_meal_recipes (
  list_id uuid not null
    references public.shared_lists (id) on delete cascade,
  meal_id uuid not null,
  source_url text not null check (length(source_url) <= 2000),
  title text not null check (length(title) <= 300),
  thumbnail_url text not null default ''
    check (length(thumbnail_url) <= 2000),
  source_type text not null default 'web'
    check (source_type in ('web', 'video')),
  updated_at timestamptz not null default now(),
  updated_by uuid default auth.uid(),
  deleted_at timestamptz,
  primary key (meal_id, source_url)
);
create index shared_meal_recipes_list_updated_idx
  on public.shared_meal_recipes (list_id, updated_at);

create trigger shared_meal_recipes_touch before insert or update
  on public.shared_meal_recipes for each row
  execute function public.touch_shared_row();

alter table public.shared_meal_recipes enable row level security;

create policy "members read meal recipes" on public.shared_meal_recipes
  for select to authenticated
  using ((select public.is_list_member(list_id)));
create policy "members add meal recipes" on public.shared_meal_recipes
  for insert to authenticated
  with check ((select public.is_list_member(list_id)));
create policy "members change meal recipes" on public.shared_meal_recipes
  for update to authenticated
  using ((select public.is_list_member(list_id)))
  with check ((select public.is_list_member(list_id)));

alter publication supabase_realtime add table public.shared_meal_recipes;
