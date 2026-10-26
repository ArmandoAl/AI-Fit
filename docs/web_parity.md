# Matriz de paridad: app móvil ↔ web (Jaspr)

Estado al 2026-10-26. «Prueba» = `apps/web/e2e/aifit.e2e.mjs` (E), `packages/core/test` (C), `packages/supabase_data/test` (S), `apps/web/test` (W).
Todo lo marcado ✔ se probó **contra un simulado del protocolo de Supabase** con datos sintéticos, no contra el proyecto real.

| Flujo | App móvil | Web | Estado | Prueba |
| --- | --- | --- | --- | --- |
| Acceso con Google | nativo (Google Sign-In) y OAuth web | OAuth + PKCE (redirección), sesión en `localStorage`, retorno con `?code=` | ✔ simulado · ⏳ real | E, W |
| Cerrar sesión | ✔ | ✔ limpia el almacenamiento | ✔ | E |
| Armario: lista, más recientes primero | ✔ | ✔ misma consulta (`SupabaseWardrobeStore`) | ✔ | E, S |
| Filtros por categoría (con sinónimos es/en) | ✔ | ✔ `WardrobeBloc` del core | ✔ | E, C |
| Selección múltiple y borrado (2 pasos + verificación de filas) | ✔ | ✔ casilla; mismos textos y orden de peticiones | ✔ | E, S, C |
| Estados cargando / error con reintento / vacío | ✔ | ✔ | ✔ | E, C |
| Procesamiento de la prenda (procesando / falló) | ✔ + reintento | ✔ se muestra; **reintentar no** (necesita el worker) | parcial | E |
| Imágenes de buckets privados | URLs firmadas | firma de rutas de Storage; URL completa tal cual | ✔ | E, W |
| Ficha de prenda | edición completa | **sólo lectura**, ruta `#/prenda/<id>` recargable | parcial | E |
| Perfil | ✔ | **sólo lectura** (datos, onboarding, fotos, identidad visual) | parcial | E |
| Teléfono 390 px / accesibilidad | n/a | 2 columnas, sin desbordar; axe WCAG A/AA sin hallazgos serios | ✔ | E |

## No portado todavía (decisión y motivo)
| Flujo | Motivo |
| --- | --- |
| Añadir prenda (foto, análisis con IA, recorte, embedding) | Necesita `ai-router` y el image-worker reales; el recorte nativo usa **Apple Vision (iOS)**; en web hay que decidir una alternativa explícita (subir imagen ya recortada o recorte en servidor) |
| Editar prenda, reprocesar | Mismo worker; la edición existe en `SupabaseWardrobeStore.update` pero no tiene pantalla |
| Looks guardados, generador de outfits, try-on, resultado | Dependen de `ai-router` y del worker, con estados de espera y límites del backend que no deben duplicarse; sin credenciales no se pueden validar |
| Estilista (chat) | Igual que lo anterior; `ChatBloc` aún depende de servicios de la app |
| Onboarding (fotos, análisis de identidad) | Subida y compresión de imágenes + IA |
| Cuenta de Google en iOS/Android nativos | Es del móvil; no aplica a la web |

No se simuló ningún resultado de IA como real. Mientras no haya credenciales, la web **no declara paridad** más allá de lo marcado ✔.

## Diferencias visuales deliberadas
Botón principal con **texto oscuro** sobre el rosa (#FF2A85): el texto claro de la app móvil da contraste 3.2:1 y no cumple AA.
La web sigue publicándose como Flutter Web (WASM) desde `apps/mobile/web` hasta aceptar la cobertura; la interfaz Jaspr no la reemplaza todavía.
