# Resumen Paso 1.5: Migración Dual de Repositorios a Supabase

## 1. Acciones Realizadas

- **Adaptación Dual de Repositorios sin Cambios Destructivos:**
  - Se implementó branching dinámico en todas las capas de datos: si `AppSupabaseClient.isInitialized && AppSupabaseClient.client != null`, las operaciones se ejecutan contra **Supabase Postgres**; de lo contrario, se dirigen de forma transparente a **Firestore**.
- **Repositorios Modificados:**
  1. `WardrobeRepositoryImpl` (`lib/features/wardrobe/data/wardrobe_repository_impl.dart`):
     - CRUD completo sobre la tabla `public.wardrobe_items`.
     - Serialización y deserialización enriquecida con `WardrobeItem.fromSupabase` y `WardrobeItem.toSupabase`.
     - **Erradicación de Antipatrones:** Las consultas filtran por `user_id` directamente en SQL (`.eq('user_id', uid)`), evitando descargas completas en memoria.
  2. `ProfileRepository` (`lib/features/profile/data/profile_repository.dart`):
     - Lectura y mutación sobre `public.profiles` y `public.user_photos`.
     - Inserción y eliminación de fotos por `user_id` y `kind` (`face`/`body`) con hashes de contenido únicos.
     - Eliminación de cuenta en cascada a través de PostgreSQL.
  3. `SavedOutfitsRepository` (`lib/features/outfit/data/saved_outfits_repository.dart`):
     - Inserción relacional dividida en `public.outfit_generations`, `public.outfits` y `public.outfit_items` (M:N).
     - **Erradicación de Antipatrones:** Se eliminó la llamada a `_loadFromStorage` (`listAll()`) y backfills lentos durante la carga de lookbook en el path de Supabase. La lectura se resuelve con una consulta SQL estructurada con orden descendente por fecha.
     - Generación forzada de **UUIDs válidos** (`Uuid().v4()`) para outfits y sesiones de generación, erradicando IDs temporales planos tipo `outfit_1`.
  4. `OutfitService` (`lib/features/outfit/services/outfit_service.dart`):
     - Se adaptó la resolución de URLs de prendas para consultar Supabase o Firestore según el backend activo.

---

## 2. Bloques de Código Clave

### Lectura y Escritura en `WardrobeRepositoryImpl` (`lib/features/wardrobe/data/wardrobe_repository_impl.dart`)
```dart
  @override
  Future<List<WardrobeItem>> getWardrobeItems() async {
    final uid = _getCurrentUserId();
    if (uid == null) return [];

    if (_isSupabaseActive) {
      final response = await AppSupabaseClient.client!
          .from('wardrobe_items')
          .select()
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      return (response as List)
          .map((row) =>
              WardrobeItem.fromSupabase(Map<String, dynamic>.from(row as Map)))
          .toList();
    }

    // Fallback: Firestore
    final snapshot = await _firestore
        .collection('wardrobe_items')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => WardrobeItem.fromJson({
      ...doc.data(),
      'id': doc.id,
    })).toList();
  }
```

### Guardado Relacional e Idempotente en `SavedOutfitsRepository` (`lib/features/outfit/data/saved_outfits_repository.dart`)
```dart
  Future<void> saveOutfit(SavedOutfit savedOutfit) async {
    final userId = _getCurrentUserId();
    if (userId == null) throw Exception('No user logged in');

    if (_isSupabaseActive) {
      final client = AppSupabaseClient.client!;
      final outfitId = _ensureUuid(savedOutfit.id);
      final generationId = const Uuid().v4();

      await client.from('outfit_generations').upsert({
        'id': generationId,
        'user_id': userId,
        'idempotency_key': 'gen_$outfitId',
        'user_prompt': savedOutfit.userPrompt,
        'intent': savedOutfit.intent.toJson(),
        'status': 'completed',
        'text_provider': 'firebase_gemini',
        'text_model': 'gemini-2.5-flash',
        'created_at': savedOutfit.createdAt.toUtc().toIso8601String(),
      }, onConflict: 'user_id, idempotency_key');

      await client.from('outfits').upsert({
        'id': outfitId,
        'generation_id': generationId,
        'user_id': userId,
        'rank': 1,
        'match_percentage': savedOutfit.matchPercentage,
        'compatibility_score': savedOutfit.compatibilityScore,
        'explanation': savedOutfit.outfit.explanation,
        'explanation_es': savedOutfit.outfit.explanationEs,
        'try_on_path': savedOutfit.tryOnImageUrl,
        'is_favorite': savedOutfit.isFavorite,
        'custom_tags': savedOutfit.customTags,
        'notes': savedOutfit.notes,
        'view_count': savedOutfit.viewCount,
        'created_at': savedOutfit.createdAt.toUtc().toIso8601String(),
      }, onConflict: 'id');

      // Enlace relacional en public.outfit_items
      final roles = [
        if (savedOutfit.outfit.topId != null) ('top', savedOutfit.outfit.topId!),
        if (savedOutfit.outfit.bottomId != null) ('bottom', savedOutfit.outfit.bottomId!),
        if (savedOutfit.outfit.shoesId != null) ('shoes', savedOutfit.outfit.shoesId!),
        if (savedOutfit.outfit.outerwearId != null) ('outerwear', savedOutfit.outfit.outerwearId!),
      ];

      for (final item in roles) {
        await client.from('outfit_items').upsert({
          'outfit_id': outfitId,
          'wardrobe_item_id': item.$2,
          'role': item.$1,
        }, onConflict: 'outfit_id, role');
      }
      return;
    }

    // Fallback: Firestore
    await _firestore
        .collection('saved_outfits')
        .doc(savedOutfit.id)
        .set(savedOutfit.toJson());
  }
```

---

## 3. Estado de la Compilación

Se ejecutó el análisis estático completo con FVM:

```bash
$ fvm flutter analyze
Analyzing AI-Fit...
No issues found! (ran in 2.2s)
```

---

## 4. Requerimientos de Acción Humana (Pruebas de Verificación)

### 1. Probar en Modo Firestore (Default)
Inicia la app sin parámetros adicionales:
```bash
fvm flutter run
```
- Realiza el flujo normal: visualiza prendas en el armario, agrega una prenda y genera un outfit.
- Revisa los logs en consola confirmando el flujo `[WardrobeRepository -> Firestore]` y `[SavedOutfitsRepository -> Firestore]`.

### 2. Probar en Modo Supabase
Inicia la app inyectando las credenciales de Supabase:
```bash
fvm flutter run \
  --dart-define=SUPABASE_URL=https://<TU-PROYECTO>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJhbGciOi...
```
- **Armario:** Sube una nueva prenda y verifica en la consola: `📦 [WardrobeRepository -> Supabase] Loading items...` y `✅ [WardrobeRepository -> Supabase] Item added: <UUID>`.
- **Lookbook:** Guarda un outfit y verifica en el Dashboard de Supabase que se hayan insertado las filas correspondientes en `outfit_generations`, `outfits` y `outfit_items` con integridad referencial.
- **Rendimiento:** Comprueba que la apertura de la página de Outfits Guardados es instantánea al no realizar llamadas N+1 a Storage.
