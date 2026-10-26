# Rendimiento web (build optimizado)

Chrome 156.0.8078.47, caché desactivada, **mediana de 5 corridas**, servidor local con gzip. Perfil «teléfono»: CPU ×4 y 4G (1.6 Mbps, 150 ms).

## Carga en frío de la pantalla de acceso: Jaspr vs. Flutter Web (WASM)
Carga en frío de la pantalla de acceso, caché desactivada, mediana de 5 corridas. Perfil teléfono: CPU x4 y 4G (1.6 Mbps/150 ms). Flutter Web = apps/mobile compilado con `flutter build web --wasm --release` (lo que publica scripts/deploy_web.sh) en una copia temporal; sus fuentes y runtime salen en parte de CDN (externalKB).

### Escritorio (sin limitar)

| Métrica | Jaspr (`apps/web`) | Flutter Web WASM (hoy) |
| --- | --- | --- |
| Bytes propios (gzip) | 139.4 KB | 1283.4 KB |
| Bytes externos (CDN) | 0 KB | 1759.2 KB |
| Peticiones | 3 | 20 |
| Interfaz lista | 97 ms | 764 ms |
| FCP | 84 ms | 764 ms |
| TBT | 0 ms | 221 ms |
| CLS | 0 | 0 |

### Teléfono (CPU ×4, 4G)

| Métrica | Jaspr (`apps/web`) | Flutter Web WASM (hoy) |
| --- | --- | --- |
| Bytes propios (gzip) | 139.4 KB | 1281.8 KB |
| Bytes externos (CDN) | 0 KB | 1479.6 KB |
| Peticiones | 3 | 16 |
| Interfaz lista | 1210 ms | 14677 ms |
| FCP | 1160 ms | 14660 ms |
| TBT | 69 ms | 1167 ms |
| CLS | 0 | 0 |

Tamaño del directorio de build: Jaspr 1.9 MB · Flutter Web WASM 45 MB. LCP no se compara: Flutter pinta en un `<canvas>` y el navegador no lo reporta.

## Interacciones del armario en Jaspr (servidor simulado)

| Métrica | Escritorio | Teléfono (CPU ×4) |
| --- | --- | --- |
| Entrar con Google hasta ver 6 prendas con imágenes | 187 ms | 489 ms |
| Filtrar por categoría | 46 ms | 52 ms |
| Abrir la ficha de una prenda | 76 ms | 62 ms |
| Confirmar y borrar una prenda | 78 ms | 143 ms |
| INP (peor evento) | 24 ms | 32 ms |
| TBT | 0 ms | 27 ms |
| Heap JS | 9.4 MB | 9.4 MB |

## Límites de esta comparación (leer antes de citarla)
- El baseline mide **sólo la pantalla de acceso**: es una pantalla casi estática en Jaspr, así que la diferencia de carga es la del runtime de Flutter, no la de una pantalla compleja. No hay baseline de Flutter Web para el armario porque exige sesión real.
- Las interacciones de Jaspr se midieron contra un **simulado local** de Supabase: no incluyen latencia de red ni del servicio real.
- Una sola máquina, Chromium 156 y datos sintéticos; el perfil «teléfono» es una emulación, no un dispositivo real.
- Reproducir: `scripts/e2e_web.sh` deja los servidores arriba sólo durante las pruebas; para medir, ver `apps/web/e2e/perf.mjs` y `perf_load.mjs`.
