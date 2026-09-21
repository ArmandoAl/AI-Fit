-- ==============================================================================
-- 0002_row_level_security.sql
-- AI-Fit Row Level Security (RLS) Policies
-- ==============================================================================

-- 1. Enable RLS on all public tables
alter table public.profiles enable row level security;
alter table public.user_photos enable row level security;
alter table public.wardrobe_items enable row level security;
alter table public.outfit_generations enable row level security;
alter table public.outfits enable row level security;
alter table public.outfit_items enable row level security;

-- 2. Profiles policies (user can only access/modify their own profile)
drop policy if exists profiles_owner_all on public.profiles;
create policy profiles_owner_all on public.profiles
  for all to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

-- 3. User photos policies (user can only access/modify their own biometric anchors)
drop policy if exists photos_owner_all on public.user_photos;
create policy photos_owner_all on public.user_photos
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- 4. Wardrobe items policies (user can only access/modify their own garments)
drop policy if exists wardrobe_owner_all on public.wardrobe_items;
create policy wardrobe_owner_all on public.wardrobe_items
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- 5. Outfit generations policies (user can only access/manage their own sessions)
drop policy if exists generations_owner_all on public.outfit_generations;
create policy generations_owner_all on public.outfit_generations
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- 6. Outfits policies (user can only access/modify their own outfits)
drop policy if exists outfits_owner_all on public.outfits;
create policy outfits_owner_all on public.outfits
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- 7. Outfit items policies (relational integrity verified against parent outfit ownership)
drop policy if exists outfit_items_owner_select on public.outfit_items;
create policy outfit_items_owner_select on public.outfit_items
  for select to authenticated
  using (
    exists (
      select 1 from public.outfits o
      where o.id = outfit_items.outfit_id
        and o.user_id = (select auth.uid())
    )
  );

drop policy if exists outfit_items_owner_manage on public.outfit_items;
create policy outfit_items_owner_manage on public.outfit_items
  for all to authenticated
  using (
    exists (
      select 1 from public.outfits o
      where o.id = outfit_items.outfit_id
        and o.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.outfits o
      where o.id = outfit_items.outfit_id
        and o.user_id = (select auth.uid())
    )
    and exists (
      select 1 from public.wardrobe_items w
      where w.id = outfit_items.wardrobe_item_id
        and w.user_id = (select auth.uid())
    )
  );
