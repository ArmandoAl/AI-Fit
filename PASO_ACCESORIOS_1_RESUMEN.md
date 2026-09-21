# PASO ACCESORIOS-1: EXPANSIÓN DE CATEGORÍAS EN FLUTTER (ONE_PIECE Y ACCESSORIES)

**Fecha:** 20 de Septiembre de 2026  
**Rol:** Senior Flutter Engineer & Data Modeler  
**Estado:** COMPLETADO CON ÉXITO (0 errores, 0 advertencias)

---

## 1. Resumen Ejecutivo
Se implementó la expansión funcional de categorías en la arquitectura de AI-Fit para soportar de manera nativa piezas únicas (`one_piece`: vestidos, enterizos, rompers) y accesorios (`accessories`: bufandas, aretes/joyas, collares, bolsos, cinturones), integrando su persistencia en Supabase, su presentación visual Dark Glam en Flutter y su composición algorítmica tanto determinista como vía gateway de IA.

---

## 2. Cambios en el Modelo de Datos

### 2.1. `WardrobeItem` ([wardrobe_item_model.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/wardrobe/domain/wardrobe_item_model.dart))
- **Constante `validCategories`:** Se definieron las 6 categorías canónicas:
  ```dart
  static const List<String> validCategories = [
    'top', 'bottom', 'one_piece', 'shoes', 'outerwear', 'accessories',
  ];
  ```
- **Diccionario `commonSubtypes`:**
  - `one_piece`: `['dress', 'jumpsuit', 'romper', 'vestido', 'enterizo']`
  - `accessories`: `['scarf', 'earrings', 'necklace', 'bag', 'belt', 'bufanda', 'aretes', 'collar', 'bolso']`
  - Se mantuvieron los subtipos canónicos para `top`, `bottom`, `shoes` y `outerwear`.
- **Getters y Normalizadores:**
  - `isOnePiece`: valida `'one_piece'`, `'one-piece'`, `'dress'`, `'vestido'`.
  - `isAccessory`: valida `'accessories'`, `'accessory'`, `'accesorio'`, `'accesorios'`.
  - `isTop`, `isBottom`, `isShoes`, `isOuterwear`.
  - `matchesCategory(String filterCategory)`: coincidencia flexible tolerando alias legacy.
  - `normalizeCategory(String raw)`: traduce variantes a `one_piece` y `accessories`.
- **Persistencia Supabase:**
  - `toSupabase()`: serializa con categoría normalizada (`'category': normalizeCategory(type)`).
  - `fromSupabase()`: deserializa normalizando `category` / `type`.

### 2.2. `WardrobePalette` ([wardrobe_palette.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/wardrobe/domain/wardrobe_palette.dart))
- Agregados a `typeLabelsEs`:
  - `'one_piece'`: 'Pieza Única'
  - `'one-piece'`: 'Pieza Única'
  - `'accessories'`: 'Accesorios'
  - `'accessory'`: 'Accesorios'
- Agregado diccionario `subtypeLabelsEs` y helper `labelSubtype(slug)` para traducción contextual al español neutral (ej. "Vestido", "Enterizo", "Bufanda", "Aretes / Joyas", "Bolso", "Collar").

### 2.3. Modelos de Outfits ([outfit_models.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/outfit/domain/outfit_models.dart))
- **`FilteredWardrobe`:** Incorpora `List<WardrobeItem> onePieces` y `List<WardrobeItem> accessories`.
- **`GeneratedOutfit`:**
  - Campos opcionales: `String? onePieceId`, `List<String> accessoryIds`.
  - **Regla `hasCompleteLook`:** Valida que el outfit cuente con `calzado` (`shoesId != null`) Y (bien una `pieza única` (`onePieceId != null`) O el par `superior e inferior` (`topId != null && bottomId != null`)).
  - `itemIds`: agrega `onePieceId` y `accessoryIds` a los IDs consolidados para la resolución de cutouts y flat-lays.

---

## 3. Formulario de Carga y Filtros en UI

### 3.1. Nuevo Componente `CategorySelector` ([category_selector.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/wardrobe/presentation/widgets/category_selector.dart))
- Widget interactivo y reutilizable con scroll horizontal suave.
- Estética Dark Glam / Y2K Cyber-Goth: fondo ciruela `#1D1626`, bordes activos con degradado Magenta Neón Draculaura (`#FF2A85`) o Menta Frankie (`#00F5D4`), e iconos representativos (`Icons.woman_rounded` para pieza única, `Icons.local_mall_rounded` para accesorios).
- Soporta modo filtro (incluyendo opción `'All'` / "Todos") y modo selector individual.

### 3.2. Pantalla de Carga de Prendas ([add_wardrobe_item_page.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/wardrobe/presentation/pages/add_wardrobe_item_page.dart))
- Integrado `CategorySelector` interactivo arriba de los formularios para selección ágil de categoría principal.
- Actualizados dropdowns de tipo para incluir `one_piece` y `accessories`.
- El dropdown de subtipo se recalcula dinámicamente según la categoría activa y muestra etiquetas localizadas mediante `WardrobePalette.labelSubtype(...)` (ej. si se elige Accesorio: Bufanda, Aretes / Joyas, Bolso, Collar, Cinturón).

### 3.3. Filtros del Armario ([wardrobe_page.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/wardrobe/presentation/pages/wardrobe_page.dart) & [wardrobe_bloc.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/wardrobe/presentation/bloc/wardrobe_bloc.dart))
- Actualizado `_filterKeys` a: `['All', 'top', 'bottom', 'one_piece', 'shoes', 'outerwear', 'accessories']`.
- `WardrobeBloc` filtra usando `item.matchesCategory(selectedCategory)`, garantizando retrocompatibilidad con ítems existentes.

---

## 4. Adaptación de las Reglas de Combinación de Outfits

### 4.1. `WardrobeSearchAlgorithm` ([wardrobe_search_algorithm.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/outfit/services/wardrobe_search_algorithm.dart))
- `filterWardrobe` y `_filterAndRankWithVectorBoost` extraen y rankean `onePieces` y `accessories` en el pool `FilteredWardrobe`.
- **Regla One-Piece en `generateRuleBasedOutfits`:** Si hay piezas únicas y zapatos, genera looks con `onePieceId`, dejando `topId = null` y `bottomId = null`. Si además hay prendas dos piezas (`top` + `bottom`), combina variedad de opciones.
- **Regla Accesorios en `generateRuleBasedOutfits`:** Adjunta 1 o 2 accesorios coordinados (`accessoryIds`) a los looks generados.

### 4.2. `OutfitGeneratorService` ([outfit_generator_service.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/outfit/services/outfit_generator_service.dart))
- Pool balanceado de candidatos estructurados: hasta 4 tops, 4 bottoms, 4 shoes, 3 outerwear, 3 one_pieces y 4 accessories.
- Deserializa `onePieceId` y `accessoryIds` de la respuesta del gateway o del fallback local.

### 4.3. `OutfitService` ([outfit_service.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/outfit/services/outfit_service.dart))
- Verificación previa flexible: no arroja error si el usuario no tiene tops/bottoms siempre que posea piezas únicas (`one_piece`) y calzado.

### 4.4. `SavedOutfitsRepository` ([saved_outfits_repository.dart](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/outfit/data/saved_outfits_repository.dart))
- Persiste en `outfit_items` los roles `'one_piece'` y `'accessory'`.
- Reconstruye fielmente `onePieceId` y `accessoryIds` al cargar los looks del usuario desde Supabase Postgres.

### 4.5. Gateway Edge Function ([ai-router/index.ts](file:///Users/armandoalvarado/Documents/AI-Fit/supabase/functions/ai-router/index.ts) y [_shared/types.ts](file:///Users/armandoalvarado/Documents/AI-Fit/supabase/functions/_shared/types.ts))
- Prompt de sistema y validación anti-alucinaciones adaptados para permitir `onePieceId` (que reemplaza `topId` y `bottomId`) y array de `accessoryIds`.

---

## 5. Verificación Estática y Pruebas Automatizadas

### 5.1. Ejecución de `fvm flutter analyze`
```bash
$ fvm flutter analyze
Analyzing AI-Fit...                                             
No issues found! (ran in 2.9s)
```

### 5.2. Ejecución de `fvm flutter test`
```bash
$ fvm flutter test
00:00 +0: loading /Users/armandoalvarado/Documents/AI-Fit/test/smoke_test.dart
00:00 +0: Supabase Cutover Smoke Tests AppSupabaseClient handles uninitialized state gracefully
00:00 +1: Supabase Cutover Smoke Tests WardrobeItem serializes to and from Supabase correctly
00:00 +2: Supabase Cutover Smoke Tests SavedOutfit serializes to and from JSON without Firebase Timestamp
00:00 +3: Supabase Cutover Smoke Tests IdentityConsistencyPrompt generates try-on prompt correctly
00:00 +4: Supabase Cutover Smoke Tests GlowingBorderCard renders child and handles taps
00:00 +5: Supabase Cutover Smoke Tests GradientPillButton renders uppercase text, icon and triggers callback
00:00 +6: Supabase Cutover Smoke Tests MatchScoreBadge displays score and status text
00:00 +7: Supabase Cutover Smoke Tests WardrobeCarouselSlot displays items and cycles with arrows
00:00 +8: Supabase Cutover Smoke Tests WardrobeItem serializes one_piece and accessories and validates helper getters
00:00 +9: Supabase Cutover Smoke Tests GeneratedOutfit validates one_piece look replacement and accessories
00:00 +10: Supabase Cutover Smoke Tests WardrobeSearchAlgorithm generates rule-based outfit with one_piece and accessories
00:00 +11: Supabase Cutover Smoke Tests CategorySelector displays chips for one_piece and accessories and handles selection
00:00 +12: All tests passed!
```
Total: **12 tests ejecutados y aprobados al 100%**.
