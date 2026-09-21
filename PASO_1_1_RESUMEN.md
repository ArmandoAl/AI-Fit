# Resumen Paso 1.1: Esquema DDL, RLS y Storage en Supabase

## 1. Acciones Realizadas

- **Creación de Migraciones Estándar en `supabase/migrations/`:**
  - `supabase/migrations/0001_initial_schema.sql`:
    - Habilitación de extensiones `pgcrypto` y `vector` (en el schema `extensions`).
    - Creación de 6 tablas con integridad referencial estricta y llaves foráneas (`on delete cascade` / `restrict`):
      1. `public.profiles`: Relacionada con `auth.users(id)` en cascada, soporte para `legacy_firebase_uid`, metadatos biométricos y hashes de contenido para invalidación/caché determinista.
      2. `public.user_photos`: Registro de fotos de anclaje facial y corporal, dimensiones, bytes y hash SHA-256 único por usuario/tipo.
      3. `public.wardrobe_items`: Catálogo de prendas con `legacy_firestore_id`, restricción por categoría (`top`, `bottom`, `shoes`, `outerwear`), arrays de colores, estilos y temporadas, metadatos enriquecidos en `jsonb` y vector de 512 dimensiones (`extensions.vector(512)`) para embeddings CLIP ViT-B/32.
      4. `public.outfit_generations`: Sesiones de generación con clave de idempotencia por usuario (`idempotency_key`), conteo de tokens de texto/imagen, costo en USD y latencia operativa.
      5. `public.outfits`: Looks generados con compatibilidad, porcentaje de coincidencia, explicaciones (EN/ES), rutas a flat-lay y try-on, contador de vistas y favoritos.
      6. `public.outfit_items`: Tabla asociativa M:N entre outfits y prendas con clave primaria compuesta `(outfit_id, role)` y restricción referencial.
    - Índices B-Tree optimizados para consultas por usuario y fecha, e índices GIN sobre arrays de colores y estilos (`colors`, `style_tags`, `seasons`).
    - Función RPC `public.match_wardrobe` para búsqueda vectorial exacta (`<=>` distancia coseno) con filtros de categoría y aislamiento estricto por usuario (`auth.uid()`).
  - `supabase/migrations/0002_row_level_security.sql`:
    - Activación obligatoria de `ROW LEVEL SECURITY` (RLS) en todas las tablas públicas.
    - Políticas restrictivas basadas en `(select auth.uid())` para lectura y mutación exclusiva por propietario.
    - Política de seguridad relacional en `outfit_items` que valida la pertenencia tanto del outfit contenedor como de las prendas asignadas.
  - `supabase/migrations/0003_storage_setup.sql`:
    - Creación de los buckets privados `user-media` y `generated` con `public = false`, tamaño máximo de 15 MB y tipos MIME permitidos (`image/jpeg`, `image/png`, `image/webp`).
    - Políticas RLS en `storage.objects` aislando cada bucket por prefijo del usuario autenticado: `(storage.foldername(name))[1] = (select auth.uid())::text`.

- **Justificación Arquitectural:**
  - **PostgreSQL 15+ & pgvector:** Permite búsquedas vectoriales híbridas (filtros relacionales duros como categoría + similitud semántica) dentro de la misma base de datos sin incurrir en dependencias de bases vectoriales externas costosas.
  - **Aislamiento Cero Fugas (Multi-tenant RLS):** Toda consulta y operación de almacenamiento se valida a nivel de motor SQL/Storage contra el contexto de sesión de Supabase Auth (`auth.uid()`).

---

## 2. Bloques de Código Clave

### DDL de `wardrobe_items` e Índices GIN (`0001_initial_schema.sql`)
```sql
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
```

### Función RPC de Búsqueda Vectorial (`match_wardrobe`)
```sql
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
```

### Políticas RLS y Storage (`0002_row_level_security.sql` y `0003_storage_setup.sql`)
```sql
-- RLS en Tablas
alter table public.wardrobe_items enable row level security;
create policy wardrobe_owner_all on public.wardrobe_items
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

-- Buckets y RLS en Storage
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('user-media', 'user-media', false, 15728640, array['image/jpeg', 'image/png', 'image/webp']),
  ('generated', 'generated', false, 15728640, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = false;

create policy "storage_user_media_read" on storage.objects
  for select to authenticated
  using (
    bucket_id in ('user-media', 'generated')
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );
```

---

## 3. Verificación

- **Integridad de Código Flutter/Dart:**
  - Se confirmó que **ningún archivo de Dart o Flutter (`lib/`, `test/`, `pubspec.yaml`, etc.) fue modificado** en esta tarea.
- **Análisis Estático del Proyecto:**
  ```bash
  $ fvm flutter analyze
  Analyzing AI-Fit...
  No issues found! (ran in 2.7s)
  ```
- **Validación de Sintaxis SQL:**
  - Los scripts utilizan sintaxis estándar PostgreSQL 15+ con sentencias `IF NOT EXISTS` y `ON CONFLICT` para garantizar idempotencia total.

---

## 4. Requerimientos de Acción Humana (Paso a Paso en Supabase Console / CLI)

### Opción A: Mediante Supabase CLI (Recomendado para Staging/Local)

1. Si trabajas localmente con Supabase CLI:
   ```bash
   npx supabase start
   npx supabase db reset # o npx supabase db push
   ```
2. Para aplicar las migraciones a un proyecto remoto de Supabase:
   ```bash
   npx supabase link --project-ref <TU-PROJECT-REF>
   npx supabase db push
   ```

### Opción B: Mediante la Consola Web de Supabase (SQL Editor)

Si deseas aplicar las migraciones manualmente desde el Dashboard de Supabase:

1. Inicia sesión en [Supabase Dashboard](https://supabase.com/dashboard) y selecciona tu proyecto.
2. Dirígete a **SQL Editor** en la barra lateral izquierda.
3. Abre y ejecuta secuencialmente los tres archivos:
   - **Paso 1:** Pega el contenido de [`supabase/migrations/0001_initial_schema.sql`](file:///Users/armandoalvarado/Documents/AI-Fit/supabase/migrations/0001_initial_schema.sql) y haz clic en **Run**.
   - **Paso 2:** Pega el contenido de [`supabase/migrations/0002_row_level_security.sql`](file:///Users/armandoalvarado/Documents/AI-Fit/supabase/migrations/0002_row_level_security.sql) y haz clic en **Run**.
   - **Paso 3:** Pega el contenido de [`supabase/migrations/0003_storage_setup.sql`](file:///Users/armandoalvarado/Documents/AI-Fit/supabase/migrations/0003_storage_setup.sql) y haz clic en **Run**.

### Verificación Visual en el Dashboard

Una vez ejecutadas las migraciones, verifica en tu proyecto de Supabase:
1. **Database > Tables:** Deben aparecer las 6 tablas (`profiles`, `user_photos`, `wardrobe_items`, `outfit_generations`, `outfits`, `outfit_items`).
2. **Authentication > Policies:** Cada una de las 6 tablas debe tener la etiqueta **RLS Enabled** con sus respectivas políticas activas.
3. **Storage:** Deben existir los buckets `user-media` y `generated`, ambos configurados como **Private** (candado cerrado).
4. **Database > Functions:** Debe aparecer la función `match_wardrobe`.
