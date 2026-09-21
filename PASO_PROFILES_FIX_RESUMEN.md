# Resumen de Corrección: Sincronización de Profiles, FK en user_photos y Multi-Image Picker

## 1. Causa Raíz Identificada

### 1.1 Incompatibilidad de Columnas en `public.profiles`
En `lib/features/auth/data/auth_repository.dart`, el método `_syncUserToProfiles` enviaba un payload con las siguientes claves:
```dart
await _supabase.from('profiles').upsert({
  'id': user.id,
  'display_name': name,
  'email': user.email ?? '',      // ❌ Columna no existe en public.profiles
  'photo_url': avatar,            // ❌ Columna no existe en public.profiles (es avatar_path)
  'updated_at': DateTime.now().toUtc().toIso8601String(),
}, onConflict: 'id');
```
El esquema de PostgreSQL definido en `supabase/migrations/0001_initial_schema.sql` establece para `public.profiles`:
- `id` (uuid, primary key)
- `legacy_firebase_uid` (text)
- `display_name` (text)
- `avatar_path` (text)
- `preferences` (jsonb)
- `onboarding_completed` (boolean)
- `identity_profile` (jsonb)
- `identity_version` (integer)
- `identity_collage_path` (text)
- `identity_content_hash` (text)
- `base_image_path` (text)
- `base_image_content_hash` (text)
- `created_at` (timestamptz)
- `updated_at` (timestamptz)

La presencia de `'email'` y `'photo_url'` generaba un error de Postgres (`column "email" of relation "profiles" does not exist`), el cual era silenciado como `non-critical` en un bloque `catch (e)`.

### 1.2 Disparo de Restricción FK en `public.user_photos`
Al no insertarse el registro en `public.profiles`, cuando el usuario avanzaba a la pantalla de onboarding fotográfico (`PhotoSetupPage`) y llamaba a `uploadFacePhotos` o `uploadBodyPhotos`, Supabase ejecutaba:
```sql
insert into public.user_photos (user_id, kind, storage_path, content_hash) ...
```
Dado que la tabla `public.user_photos` define:
```sql
user_id uuid not null references public.profiles(id) on delete cascade
```
Postgres abortaba la transacción arrojando:
`user_photos_user_id_fkey (code: 23503)` porque el registro padre en `profiles` no existía.

---

## 2. Soluciones Implementadas

### 2.1 Sincronización Limpia y Robusta en `AuthRepository`
**Archivo modificado:** [auth_repository.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/auth/data/auth_repository.dart)

- Se depuró el payload enviado al método `upsert` en `public.profiles`, usando únicamente columnas válidas:
  ```dart
  final payload = <String, dynamic>{
    'id': user.id,
    'display_name': name,
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
  if (avatar.isNotEmpty) {
    payload['avatar_path'] = avatar;
  }
  ```
- **Mecanismo de Fallback Defensivo:** Si el upsert fallara por algún campo opcional, se reintenta inmediatamente con el payload estrictamente indispensable (`id` y `updated_at`).
- Se expuso el método de forma pública como `ensureProfileSynced(User user)` y se re-lanzan los errores críticos si ambos intentos fallan, evitando que downstream continúe a ciegas.

### 2.2 Salvaguarda Defensiva de Foreign Key en `ProfileRepository`
**Archivo modificado:** [profile_repository.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/profile/data/profile_repository.dart)

- Se implementó el método:
  ```dart
  Future<void> ensureProfileExists(String userId) async {
    try {
      final existing = await _supabase
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('profiles').upsert({
          'id': userId,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'id');
      }
    } catch (e) {
      // Intento forzado de upsert si falló la consulta previa
      await _supabase.from('profiles').upsert({
        'id': userId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'id');
    }
  }
  ```
- Se integró `await ensureProfileExists(userId);` como primera instrucción en:
  - `uploadFacePhotos`
  - `uploadBodyPhotos`
  - Flujo de confirmación en `PhotoSetupPage._continue()`
  Garantizando que nunca se produzca una inserción en `user_photos` sin que el registro de `profiles` exista previamente.

### 2.3 Selección Múltiple de Fotos en Onboarding (`pickMultiImage`)
**Archivo modificado:** [photo_setup_page.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/auth/presentation/pages/photo_setup_page.dart)

- Se reemplazó la llamada individual `_picker.pickImage` por `_picker.pickMultiImage(imageQuality: 85, limit: remainingSlots)`.
- El usuario ahora puede seleccionar hasta las 4 fotos de una sola vez desde la galería nativa tanto en la sección **Cara** como en **Cuerpo completo**, sin tener que hacer click 4 veces independientes.
- Se calculan dinámicamente los cupos disponibles (`remainingSlots = _maxPerSection - list.length`) y se aplica `images.take(remainingSlots)` para proteger la interfaz ante sobre-selección en cualquier plataforma.
- Procesamiento en paralelo de los archivos seleccionados mediante `Future.wait` y un único refresco de estado (`setState`).

---

## 3. Pruebas y Validación Estática

### 3.1 Pruebas Unitarias Agregadas
**Archivo:** [smoke_test.dart](file:///Users/armandoalvarado/Documents/AI-Fit/test/smoke_test.dart)
- `Profiles standard payload schema validation`: Comprueba que el payload enviado a `profiles` solo utilice columnas permitidas en la base de datos Supabase y no incluya `email` o `photo_url`.
- `Multi-image picker slots and limiting logic`: Valida la lógica de cálculo de slots restantes y limitación defensiva de fotos al seleccionar en bloque.

### 3.2 Resultados de Análisis y Tests
- `fvm flutter analyze`: **0 issues found** (código 100% limpio).
- `fvm flutter test`: **20 de 20 tests pasados exitosamente**.
