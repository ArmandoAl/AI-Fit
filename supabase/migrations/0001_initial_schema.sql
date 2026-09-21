-- ==============================================================================
-- 0001_initial_schema.sql
-- AI-Fit Core Relational Schema & Vector Extension Setup
-- ==============================================================================

-- 1. Extensions
create extension if not exists pgcrypto;
create extension if not exists vector with schema extensions;

-- 2. Profiles table (linked to auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  legacy_firebase_uid text unique,
  display_name text not null default '',
  avatar_path text,
  preferences jsonb not null default '{}'::jsonb,
  onboarding_completed boolean not null default false,
  identity_profile jsonb,
  identity_version integer,
  identity_collage_path text,
  identity_content_hash text,
  base_image_path text,
  base_image_content_hash text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- 3. User photos table (face & body anchors)
create table if not exists public.user_photos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null check (kind in ('face', 'body')),
  storage_path text not null unique,
  content_hash text not null,
  width integer check (width > 0),
  height integer check (height > 0),
  bytes integer check (bytes > 0),
  position smallint not null default 0,
  created_at timestamptz not null default now(),
  unique (user_id, kind, content_hash)
);

create index if not exists user_photos_user_idx
  on public.user_photos (user_id, kind, position);

-- 4. Wardrobe items table (catalog, CLIP ViT-B/32 512-dim embedding)
create table if not exists public.wardrobe_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  legacy_firestore_id text,
  name text not null,
  category text not null check (category in ('top', 'bottom', 'shoes', 'outerwear')),
  subtype text not null,
  brand text,
  source_path text not null,
  cutout_path text,
  content_hash text not null,
  colors text[] not null default '{}',
  style_tags text[] not null default '{}',
  seasons text[] not null default '{}',
  ai_metadata jsonb not null default '{}'::jsonb,
  embedding extensions.vector(512),
  embedding_model text,
  processing_status text not null default 'pending'
    check (processing_status in ('pending', 'processing', 'ready', 'failed')),
  processing_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, legacy_firestore_id),
  unique (user_id, content_hash)
);

create index if not exists wardrobe_items_owner_category_idx
  on public.wardrobe_items (user_id, category, created_at desc);

create index if not exists wardrobe_items_colors_gin
  on public.wardrobe_items using gin (colors);

create index if not exists wardrobe_items_style_tags_gin
  on public.wardrobe_items using gin (style_tags);

create index if not exists wardrobe_items_seasons_gin
  on public.wardrobe_items using gin (seasons);

-- 5. Outfit generations table (session idempotency, LLM cost & operational metrics)
create table if not exists public.outfit_generations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  idempotency_key text not null,
  user_prompt text not null,
  intent jsonb not null,
  status text not null default 'pending'
    check (status in ('pending', 'selecting', 'ready', 'rendering', 'completed', 'failed')),
  text_provider text,
  text_model text,
  image_provider text,
  image_model text,
  input_tokens bigint not null default 0,
  output_tokens bigint not null default 0,
  estimated_cost_usd numeric(12, 6) not null default 0,
  latency_ms integer,
  error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, idempotency_key)
);

create index if not exists outfit_generations_user_created_idx
  on public.outfit_generations (user_id, created_at desc);

-- 6. Outfits table (composed looks, scores, render paths)
create table if not exists public.outfits (
  id uuid primary key default gen_random_uuid(),
  generation_id uuid not null references public.outfit_generations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  rank smallint not null check (rank between 1 and 10),
  match_percentage smallint not null default 0 check (match_percentage between 0 and 100),
  compatibility_score real not null default 0 check (compatibility_score between 0 and 1),
  explanation text not null default '',
  explanation_es text not null default '',
  try_on_path text,
  flat_lay_path text,
  is_favorite boolean not null default false,
  custom_tags text[] not null default '{}',
  notes text,
  view_count bigint not null default 0,
  last_viewed_at timestamptz,
  created_at timestamptz not null default now(),
  unique (generation_id, rank)
);

create index if not exists outfits_owner_created_idx
  on public.outfits (user_id, created_at desc);

create index if not exists outfits_owner_favorite_idx
  on public.outfits (user_id, is_favorite, created_at desc);

-- 7. Outfit items junction table (strict referential integrity M:N)
create table if not exists public.outfit_items (
  outfit_id uuid not null references public.outfits(id) on delete cascade,
  wardrobe_item_id uuid not null references public.wardrobe_items(id) on delete restrict,
  role text not null check (role in ('top', 'bottom', 'shoes', 'outerwear')),
  primary key (outfit_id, role),
  unique (outfit_id, wardrobe_item_id)
);

create index if not exists outfit_items_wardrobe_item_idx
  on public.outfit_items (wardrobe_item_id);

-- 8. Vector similarity search function (match_wardrobe RPC)
create or replace function public.match_wardrobe(
  query_embedding extensions.vector(512),
  category_filter text default null,
  match_count integer default 12
)
returns table (
  id uuid,
  category text,
  similarity real,
  metadata jsonb
)
language sql
stable
security invoker
set search_path = public, extensions
as $$
  select w.id,
         w.category,
         (1 - (w.embedding <=> query_embedding))::real as similarity,
         jsonb_build_object(
           'name', w.name,
           'subtype', w.subtype,
           'colors', w.colors,
           'styleTags', w.style_tags,
           'ai', w.ai_metadata
         ) as metadata
  from public.wardrobe_items w
  where w.user_id = (select auth.uid())
    and w.processing_status = 'ready'
    and w.embedding is not null
    and (category_filter is null or w.category = category_filter)
  order by w.embedding <=> query_embedding
  limit least(greatest(match_count, 1), 50);
$$;
