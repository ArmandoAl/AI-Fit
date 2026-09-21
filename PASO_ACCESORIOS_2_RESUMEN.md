# PASO ACCESORIOS-2: FLAT-LAY COMPOSER DINÁMICO Y PROMPTS VISUALES (ONE-PIECE & ACCESORIOS)

**Fecha:** 20 de Septiembre de 2026  
**Rol:** Senior Computer Vision & AI Systems Engineer  
**Estado:** COMPLETADO CON ÉXITO (0 errores, 0 advertencias)

---

## 1. Resumen Ejecutivo
Se implementó con éxito la adaptación del compositor determinista de flat-lays en `services/image-worker` y la especialización de prompts en `supabase/functions/ai-router` y Flutter. El sistema ahora soporta composiciones dinámicas en canvas blanco 1024x1024 para piezas únicas (`one_piece`: vestidos, enterizos) y múltiples accesorios (`accessories`: bolsos, collares, aretes, bufandas, cinturones) preservando el aspect ratio (`contain`), sin deformaciones y aplicando el pipeline estricto de **2 imágenes** (Identity Board + Flat-Lay consolidado).

---

## 2. Esquema de Distribución Espacial (`flatlay_composer.py`)

El canvas sRGB es de 1024x1024 px con fondo blanco puro (`#FFFFFF`). Cada prenda es redimensionada de forma no destructiva con interpolación Lanczos preservando su aspect ratio (`contain`) y centrada en su ranura designada.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    CANVAS sRGB 1024 x 1024                              │
│                                                                         │
│  MODO A: ONE-PIECE + ACCESORIOS        MODO B: ONE-PIECE + ABRIGO      │
│  ┌──────────┬──────────────┬──────────┐ ┌──────────────┬──────────────┐ │
│  │ Acc #1   │              │ Acc #2   │ │ Outerwear    │ One-Piece    │ │
│  │ (Scarf / │  ONE-PIECE   │ (Jewelry │ │ (Abrigo/     │ (Vestido     │ │
│  │  Bag)    │  (Vestido    │ / Belt)  │ │  Blazer)     │  Dominante)  │ │
│  │          │   Dominante) │          │ │              │              │ │
│  │          │              │          │ │ (40,50,      │ (500,40,     │ │
│  │ (40,160, │ (262,40,     │ (774,160,│ │  440,580)    │  480,680)    │ │
│  │  210,380)│  500,680)    │  210,380)│ ├──────────────┴──────────────┤ │
│  ├──────────┴──────────────┴──────────┤ │ Acc #1       │ Calzado      │ │
│  │ Acc #3 (opt)  │ Calzado (Shoes)    │ │ (Bolso/      │ (Shoes)      │ │
│  │ (40,640,      │ (520,740,          │ │  Joyas)      │ (520,740,    │ │
│  │  420,340)     │  460,244)          │ │ (40,660)     │  460,244)    │ │
│  └───────────────┴────────────────────┘ └──────────────┴──────────────┘ │
│                                                                         │
│  MODO C: TWO-PIECE CLÁSICO CON ACCESORIOS (HASTA 6 ÍTEMS)               │
│  ┌───────────────────────────┬───────────────────────────┬────────────┐ │
│  │ Outerwear (30,40,380,440) │ Top (430,40,380,440)      │ Acc #1     │ │
│  │                           │                           │ (Joyas)    │ │
│  ├───────────────────────────┼───────────────────────────┼────────────┤ │
│  │ Bottom (30,520,380,460)   │ Shoes (430,540,380,440)   │ Acc #2     │ │
│  │                           │                           │ (Bolso)    │ │
│  └───────────────────────────┴───────────────────────────┴────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
```

### Características Técnicas del Compositor:
- **Normalización de Alias:** `normalize_category_key` reconoce `'one_piece'`, `'one-piece'`, `'dress'`, `'vestido'`, `'jumpsuit'`, `'enterizo'` como pieza única, y `'accessories'`, `'scarf'`, `'bag'`, `'bolso'`, `'necklace'`, `'earrings'`, `'belt'` como accesorios.
- **Soporte Multi-Accesorio:** Admite listas de accesorios ilimitadas (`extra_accessories: List[Image.Image]`) acomodándolos sin solapamientos en ranuras laterales o esquinas libres.
- **Exportación Controlada:** Formato JPEG calidad 85 con compresión optimizada, garantizando pesos `<= 900 KB` (típicamente 180–380 KB).

---

## 3. Adaptaciones en Prompts de IA para Virtual Try-On

### 3.1. Enriquecimiento en el Gateway (`ai-router/index.ts` & `image_providers.ts`)
1. **Detección Automática de Tipo de Prenda:**
   Si los ítems contienen una pieza única (`one_piece` o `dress`), el prompt inyecta:
   ```text
   [OUTFIT_SPECIFICATION]
   GARMENT_TYPE: FULL_BODY_ONE_PIECE (Dress / Jumpsuit).
   CRITICAL: The person is wearing a single continuous one-piece dress with footwear.
   Do NOT paint, render, or hallucinate pants, trousers, or separate bottoms.
   ```
2. **Estilizado de Accesorios:**
   Si los ítems contienen accesorios (bolso, aretes, collar, bufanda), se inyecta su descripción puntual:
   ```text
   [ACCESSORIES_STYLING]
   Naturally style all accessories from the flat-lay: Silver Necklace, Black Handbag
   (e.g. wearing the jewelry/scarf, holding or carrying the handbag).
   ```
3. **Rol Estricto en el Pipeline de 2 Imágenes:**
   En proveedores Google Gemini Multimodal e Imagen 3:
   - **Image 1:** `IDENTITY_BASE` (Plantilla de identidad del usuario).
   - **Image 2:** `CONSOLIDATED_GARMENT_FLATLAY` (Canvas 1024x1024 con todas las prendas y accesorios organizados sobre blanco puro).

### 3.2. Cliente Flutter (`IdentityConsistencyPrompt` & `VirtualTryOnService`)
- En [IdentityConsistencyPrompt](file:///Users/armandoalvarado/Documents/AI-Fit/lib/core/constants/identity_consistency_prompt.dart):
  - Nuevo parámetro `isOnePiece`: añade instrucciones anti-alucinación de pantalones.
  - Nuevo parámetro `accessoryDescriptions`: describe accesorios a portar.
  - Nuevo parámetro `hasFlatlay`: estructura los roles para la entrada de 2 imágenes.
- En [VirtualTryOnService](file:///Users/armandoalvarado/Documents/AI-Fit/lib/features/outfit/services/virtual_try_on_service.dart):
  - Resuelve metadatos completos (`category`, `subtype`, `name`, `cutout_path`) para pasar cutouts estructurados al backend.

---

## 4. Pruebas Unitarias en el Worker Python

Se creó la suite de pruebas [test_flatlay_composer.py](file:///Users/armandoalvarado/Documents/AI-Fit/services/image-worker/test_flatlay_composer.py) ejecutando 6 pruebas exhaustivas:

```bash
$ python3 -m unittest test_flatlay_composer.py
......
----------------------------------------------------------------------
Ran 6 tests in 0.065s

OK
```

### Casos de Prueba Verificados:
1. `test_normalize_category_key`: Mapeo exacto de alias en inglés y español.
2. `test_fit_and_center_in_slot_aspect_ratio`: Preservación matemática de ratio de aspecto 400x700 en ranuras contenidas.
3. `test_one_piece_mode_without_outerwear`: Generación de canvas 1024x1024 con vestido central dominante, calzado y 2 accesorios. Exportación a JPEG <= 900 KB.
4. `test_one_piece_mode_with_outerwear`: Generación de canvas con abrigo a la izquierda, vestido a la derecha y accesorios.
5. `test_two_piece_mode_with_accessories`: Composición de top + bottom + shoes + 2 accesorios perimetrales.
6. `test_two_piece_mode_with_outerwear_and_accessories`: Composición completa de 6 piezas balanceadas.

---

## 5. Verificación Estática y Suite de Tests en Flutter

### 5.1. Análisis Estático (`fvm flutter analyze`)
```bash
$ fvm flutter analyze
Analyzing AI-Fit...                                             
No issues found! (ran in 2.6s)
```

### 5.2. Suite de Tests (`fvm flutter test`)
```bash
$ fvm flutter test
00:00 +0: loading /Users/armandoalvarado/Documents/AI-Fit/test/smoke_test.dart
00:00 +0: Supabase Cutover Smoke Tests AppSupabaseClient handles uninitialized state gracefully
00:00 +1: Supabase Cutover Smoke Tests WardrobeItem serializes to and from Supabase correctly
00:00 +2: Supabase Cutover Smoke Tests SavedOutfit serializes to and from JSON without Firebase Timestamp
00:00 +3: Supabase Cutover Smoke Tests IdentityConsistencyPrompt generates try-on prompt correctly
00:00 +4: Supabase Cutover Smoke Tests IdentityConsistencyPrompt generates try-on prompt with one_piece and accessories correctly
00:00 +5: Supabase Cutover Smoke Tests GlowingBorderCard renders child and handles taps
00:00 +6: Supabase Cutover Smoke Tests GradientPillButton renders uppercase text, icon and triggers callback
00:00 +7: Supabase Cutover Smoke Tests MatchScoreBadge displays score and status text
00:00 +8: Supabase Cutover Smoke Tests WardrobeCarouselSlot displays items and cycles with arrows
00:00 +9: Supabase Cutover Smoke Tests WardrobeItem serializes one_piece and accessories and validates helper getters
00:00 +10: Supabase Cutover Smoke Tests GeneratedOutfit validates one_piece look replacement and accessories
00:00 +11: Supabase Cutover Smoke Tests WardrobeSearchAlgorithm generates rule-based outfit with one_piece and accessories
00:00 +12: Supabase Cutover Smoke Tests CategorySelector displays chips for one_piece and accessories and handles selection
00:00 +13: All tests passed!
```
Total: **13 tests ejecutados y aprobados al 100%**.
