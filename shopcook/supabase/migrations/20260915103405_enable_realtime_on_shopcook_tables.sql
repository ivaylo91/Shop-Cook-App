-- Realtime, so a partner ticking milk off shows up on your screen while you
-- are standing in the shop. RLS still applies to the stream, so a client only
-- receives changes to rows its own policies would let it read.
--
-- Separate from the schema migration on purpose: if the publication is not
-- present this fails on its own rather than rolling back the tables.
alter publication supabase_realtime add table public.shopping_lists;
alter publication supabase_realtime add table public.meals;
alter publication supabase_realtime add table public.products;
alter publication supabase_realtime add table public.recipes;
