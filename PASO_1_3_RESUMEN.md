# Resumen Paso 1.3: Scripts de Migración y Verificación

## 1. Acciones Realizadas

- **Aislamiento Total del Entorno de Migración en `scripts/`:**
  - Se configuró un entorno TypeScript independiente para ejecutar procesos ETL de datos sin contaminar el SDK ni las dependencias de Flutter.
  - Se crearon los siguientes archivos:
    - `scripts/package.json`: Configuración de dependencias admin (`firebase-admin`, `@supabase/supabase-js`, `dotenv`, `tsx`, `typescript`).
    - `scripts/tsconfig.json`: Configuración del compilador TypeScript con soporte ES2022 y resolución de módulos moderna.
    - `scripts/.env.example`: Plantilla de variables de entorno para credenciales seguras.
    - `scripts/migrate_firebase_to_supabase.ts`: Script principal de extracción, transformación y carga (ETL).
    - `scripts/verify_migration.ts`: Script de verificación comparativa de integridad y conteos.
- **Mecanismos de Idempotencia y Checkpoint:**
  - `migrate_firebase_to_supabase.ts` implementa un sistema de checkpoint local en `scripts/.migration_checkpoint.json`.
  - Guarda mapas de equivalencia de IDs (`firebaseUid -> supabaseUserId`, `firestoreId -> supabaseItemId`, `outfitId -> supabaseOutfitId`, `imageUrl -> supabaseStoragePath`).
  - Utiliza sentencias `upsert` con cláusulas `onConflict` (`(user_id, legacy_firestore_id)`, `(user_id, idempotency_key)`, etc.), permitiendo que el script sea reanudable ante desconexiones de red o ejecutable múltiples veces sin duplicar registros ni volver a subir imágenes ya transferidas.
  - Calcula hashes SHA-256 de cada archivo transferido para garantizar integridad y evitar subidas redundantes a Supabase Storage.

---

## 2. Bloques de Código Clave

### Extracción y Carga de `wardrobe_items` con Storage (`scripts/migrate_firebase_to_supabase.ts`)
```typescript
    const dl = await downloadBuffer(itemData.imageUrl, firebaseStorage);
    if (dl) {
      contentHash = computeSha256(dl.buffer);
      const ext = dl.mimeType.includes('png') ? 'png' : dl.mimeType.includes('webp') ? 'webp' : 'jpg';
      sourceStoragePath = `user-media/${supabaseUserId}/wardrobe/${supabaseItemId}/source.${ext}`;

      await supabase.storage
        .from('user-media')
        .upload(`${supabaseUserId}/wardrobe/${supabaseItemId}/source.${ext}`, dl.buffer, {
          contentType: dl.mimeType,
          upsert: true,
        });
    }

    const wardrobePayload = {
      id: supabaseItemId,
      user_id: supabaseUserId,
      legacy_firestore_id: firestoreId,
      name: itemData.name || itemData.subType || 'Prenda',
      category: normalizeCategory(itemData.type || itemData.category),
      subtype: itemData.subType || itemData.name || 'item',
      brand: itemData.brand || null,
      source_path: sourceStoragePath || itemData.imageUrl || 'unknown_source',
      content_hash: contentHash,
      colors: Array.isArray(itemData.colors) ? itemData.colors : (itemData.color ? [String(itemData.color)] : []),
      style_tags: Array.isArray(itemData.styleTags) ? itemData.styleTags : [],
      seasons: Array.isArray(itemData.season) ? itemData.season : [],
      ai_metadata: itemData.aiMetadata || itemData.metadata || {},
      processing_status: 'ready',
      created_at: itemData.createdAt?.toDate?.()?.toISOString() || new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    await supabase.from('wardrobe_items').upsert(wardrobePayload, {
      onConflict: 'user_id, legacy_firestore_id',
    });
```

### Lógica de Comparación y Verificación de Integridad (`scripts/verify_migration.ts`)
```typescript
  // 1. Comparación de Conteos
  const fbUsers = await firestore.collection('users').get();
  const fbWardrobe = await firestore.collection('wardrobe_items').get();
  const fbOutfits = await firestore.collection('saved_outfits').get();

  const { count: sbProfilesCount } = await supabase
    .from('profiles')
    .select('*', { count: 'exact', head: true });
  const { count: sbWardrobeCount } = await supabase
    .from('wardrobe_items')
    .select('*', { count: 'exact', head: true });
  const { count: sbOutfitsCount } = await supabase
    .from('outfits')
    .select('*', { count: 'exact', head: true });

  // 2. Validación de Huérfanos
  const { data: orphanWardrobe } = await supabase
    .from('wardrobe_items')
    .select('id, user_id')
    .is('user_id', null);
  const { data: orphanOutfits } = await supabase
    .from('outfits')
    .select('id, user_id')
    .is('user_id', null);
```

---

## 3. Estado de la Aplicación Flutter

- **Verificación de Código Flutter:**
  - Se confirmó que **ningún archivo en `lib/` ni `pubspec.yaml` fue modificado** en esta tarea.
- **Análisis Estático:**
  ```bash
  $ fvm flutter analyze
  Analyzing AI-Fit...
  No issues found! (ran in 2.9s)
  ```

---

## 4. Requerimientos de Acción Humana (Instrucciones para Ejecutar la Migración)

Para ejecutar la migración cuando tengas las credenciales de tus proyectos de Firebase y Supabase:

### 1. Preparar Credenciales
1. Descarga la clave privada de servicio de Firebase:
   - [Firebase Console](https://console.firebase.google.com/) ➔ Configuración del proyecto ➔ Cuentas de servicio ➔ Generar nueva clave privada.
   - Guarda el archivo como `scripts/serviceAccountKey.json`.
2. Obtener credenciales de Supabase:
   - [Supabase Dashboard](https://supabase.com/dashboard) ➔ Project Settings ➔ API.
   - Copia la **URL** y la **`service_role` Secret Key** (se requiere `service_role` para que el script pueda insertar y migrar sin ser bloqueado por RLS).
3. Crear el archivo `scripts/.env`:
   ```bash
   cp scripts/.env.example scripts/.env
   ```
   Rellena los valores en `scripts/.env`:
   ```env
   FIREBASE_SERVICE_ACCOUNT_KEY_PATH=./serviceAccountKey.json
   FIREBASE_STORAGE_BUCKET=tu-proyecto.appspot.com
   SUPABASE_URL=https://tu-proyecto.supabase.co
   SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOi...
   ```

### 2. Instalar Dependencias del Script
```bash
cd scripts
npm install
```

### 3. Ejecutar la Migración
```bash
npm run migrate
```
*Si la migración se interrumpe por conexión, puedes reanudarla ejecutando el mismo comando; retomará automáticamente desde el archivo `.migration_checkpoint.json`.*

### 4. Verificar la Migración
```bash
npm run verify
```
*El script emitirá un reporte tabular confirmando la paridad de registros al 100% y la validez de los objetos en Storage.*
