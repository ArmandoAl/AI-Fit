-- ==============================================================================
-- 0003_storage_setup.sql
-- AI-Fit Supabase Storage Buckets & Isolation Policies
-- ==============================================================================

-- 1. Create private buckets in storage.buckets
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  (
    'user-media',
    'user-media',
    false,
    15728640, -- 15 MB
    array['image/jpeg', 'image/png', 'image/webp']
  ),
  (
    'generated',
    'generated',
    false,
    15728640, -- 15 MB
    array['image/jpeg', 'image/png', 'image/webp']
  )
on conflict (id) do update set
  public = false,
  file_size_limit = 15728640,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

-- 2. Storage Objects RLS Policies for user-media and generated buckets
-- Each authenticated user can only access/mutate objects prefixed with their auth.uid()

drop policy if exists "storage_user_media_read" on storage.objects;
create policy "storage_user_media_read" on storage.objects
  for select to authenticated
  using (
    bucket_id in ('user-media', 'generated')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_user_media_insert" on storage.objects;
create policy "storage_user_media_insert" on storage.objects
  for insert to authenticated
  with check (
    bucket_id in ('user-media', 'generated')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_user_media_update" on storage.objects;
create policy "storage_user_media_update" on storage.objects
  for update to authenticated
  using (
    bucket_id in ('user-media', 'generated')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id in ('user-media', 'generated')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "storage_user_media_delete" on storage.objects;
create policy "storage_user_media_delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id in ('user-media', 'generated')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
