# Resumen Paso 1.4: Abstracción Dual de Storage Service

## 1. Acciones Realizadas

- **Refactorización de `StorageService` (`lib/core/services/storage_service.dart`):**
  - Se mantuvo **100% estable la API pública** (`uploadUserPhoto`, `uploadMultiplePhotos`, `uploadWardrobeItem`, `uploadUserBaseImage`, `uploadOutfitTryOn`, `uploadIdentityCollage`, `deletePhoto`, `deleteMultiplePhotos`), evitando romper UI o repositorios existentes.
  - **Detección Dinámica de MIME & Extensión:** Se implementaron helpers de detección de firmas binarias (magic numbers) para `image/png`, `image/webp` y `image/jpeg` en lugar de forzar `.jpg` a ciegas.
  - **Manejo de Buckets Privados con Signed URLs:** Para Supabase Storage, las operaciones de subida generan automáticamente URLs firmadas con un TTL de 2 horas (`7200s`), permitiendo que cualquier componente HTTP (`CachedNetworkImage`, `Dio`, `Image.network`) consuma la imagen de forma directa y segura.
- **Resolución de Branching / Feature Flag:**
  - El servicio consulta `isSupabaseActive` (`AppSupabaseClient.isInitialized && AppSupabaseClient.client != null`).
  - Si Supabase está activo con credenciales válidas, despacha a los buckets `user-media` y `generated`.
  - Si no, delega transparentemente a Firebase Storage sin alterar la experiencia de desarrollo.
- **Rutas Deterministas en Supabase Storage:**
  - Prendas: `user-media/{userId}/wardrobe/item_{timestamp}.{ext}`
  - Fotos de perfil / anclaje: `user-media/{userId}/photos/{photoType}_{timestamp}.{ext}`
  - Base Image & Collage: `generated/{userId}/identity/{base|collage}_{timestamp}.{ext}`
  - Try-on: `generated/{userId}/tryons/tryon_{timestamp}.{ext}`
- **Desacoplamiento en Servicios de Perfil:**
  - Se actualizó `UserIdentityAnalysisService` para utilizar la abstracción de `StorageService` en `_uploadCollage` en lugar de acceder directamente a `FirebaseStorage`.
- **Compatibilidad en `AppNetworkImage` y `NetworkImageLoader`:**
  - `NetworkImageLoader` procesa cualquier URL HTTPS mediante `Dio` (incluyendo URLs firmadas con parámetros de token de Supabase).
  - `AppNetworkImage` delega URLs de Supabase y URLs externas a `CachedNetworkImage` manteniendo el bypass de CORS específico de Firebase únicamente para el dominio `firebasestorage.googleapis.com`.

---

## 2. Bloques de Código Clave

### Branching y Upload en `StorageService` (`lib/core/services/storage_service.dart`)
```dart
  bool get isSupabaseActive =>
      AppSupabaseClient.isInitialized && AppSupabaseClient.client != null;

  Future<String> _uploadToSupabase({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final supabase = AppSupabaseClient.client!;
    debugPrint('📤 [StorageService -> Supabase] Uploading to $bucket/$path ($mimeType)');

    await supabase.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: true,
          ),
        );

    // Generate signed URL with 2 hour TTL for private buckets
    final signedUrl = await supabase.storage.from(bucket).createSignedUrl(
          path,
          7200,
        );

    debugPrint('✅ [StorageService -> Supabase] Upload complete: $signedUrl');
    return signedUrl;
  }
```

### Operación de Guardado de Prenda con Detección de MIME
```dart
  Future<String> uploadWardrobeItem({
    required String userId,
    required AppImage image,
  }) async {
    _assertAuthenticatedUpload(userId);
    if (image.bytes.isEmpty) throw Exception('Image is empty');

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final mime = detectMimeType(image.bytes);
    final ext = extensionForMime(mime);

    if (isSupabaseActive) {
      final path = '$userId/wardrobe/item_$timestamp.$ext';
      return await _uploadToSupabase(
        bucket: 'user-media',
        path: path,
        bytes: image.bytes,
        mimeType: mime,
      );
    }

    final path = 'users/$userId/wardrobe/item_$timestamp.$ext';
    return await _uploadToFirebase(
      path: path,
      bytes: image.bytes,
      contentType: mime,
      customMetadata: {
        'userId': userId,
        'itemType': 'wardrobe',
        'uploadedAt': timestamp.toString(),
      },
    );
  }
```

### Eliminación Polimórfica (`deletePhoto`)
```dart
  Future<void> deletePhoto(String downloadUrl) async {
    try {
      if (isSupabaseActive && downloadUrl.contains('storage/v1/object')) {
        final supabase = AppSupabaseClient.client!;
        final uri = Uri.parse(downloadUrl);
        final segments = uri.pathSegments;
        final objectIdx = segments.indexOf('object');
        if (objectIdx != -1 && segments.length > objectIdx + 2) {
          final isSign = segments[objectIdx + 1] == 'sign' ||
              segments[objectIdx + 1] == 'public' ||
              segments[objectIdx + 1] == 'authenticated';
          final bucket = isSign ? segments[objectIdx + 2] : segments[objectIdx + 1];
          final pathStartIndex = isSign ? objectIdx + 3 : objectIdx + 2;
          final objectPath = segments.sublist(pathStartIndex).join('/');
          await supabase.storage.from(bucket).remove([objectPath]);
          debugPrint('🗑️ [StorageService -> Supabase] Deleted $bucket/$objectPath');
          return;
        }
      }

      final ref = _firebaseStorage.refFromURL(downloadUrl);
      await ref.delete();
      debugPrint('🗑️ [StorageService -> Firebase] Deleted $downloadUrl');
    } catch (e) {
      debugPrint('⚠️ [StorageService] deletePhoto error: $e');
      throw Exception('Failed to delete photo: $e');
    }
  }
```

---

## 3. Estado de la Compilación

Se ejecutó la verificación estática completa con FVM:

```bash
$ fvm flutter analyze
Analyzing AI-Fit...
No issues found! (ran in 2.3s)
```

---

## 4. Requerimientos de Acción Humana (Pruebas de Verificación)

Para probar la abstracción dual de Storage en desarrollo:

### 1. Probar en Modo Firebase (Comportamiento por Defecto)
Ejecuta la app sin flags de Supabase:
```bash
fvm flutter run
```
- Sube una nueva prenda o foto de onboarding.
- Verifica en consola: `📤 [StorageService -> Firebase] Uploading to users/...`

### 2. Probar en Modo Supabase (Con Flags de Compilación)
Ejecuta la app inyectando las credenciales de Supabase:
```bash
fvm flutter run \
  --dart-define=SUPABASE_URL=https://<TU-PROYECTO>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
```
- Sube una nueva prenda o genera un outfit / try-on.
- Verifica en consola: `📤 [StorageService -> Supabase] Uploading to user-media/...`
- Verifica que el enlace retornado sea una URL firmada válida y la imagen se renderice correctamente en la UI.
