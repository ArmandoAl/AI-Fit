# Desarrollo desde el servidor (AI-Fit)

Verificado el 2026-10-26 en `hpmeserver` (Ubuntu 26.04, x86_64) en la rama `migration/jaspr-server-20261026`
(base `main` @ `a511c54`). El desarrollo se hace sobre un **checkout local del servidor** (`~/projects/AI-Fit`) con un agente
y terminal; la Mac conserva Xcode, firma e iPhone y se sincroniza por Git.

## Estructura
```text
pubspec.yaml            workspace de Pub: packages/core, packages/supabase_data, apps/mobile, apps/web   (pubspec.lock raíz)
apps/mobile/            app Flutter original (flutter_bloc, GetIt, GoRouter, Supabase, Google Sign-In) movida con git mv;
                        incluye su carpeta web/ de Flutter Web, que sigue siendo lo que publica scripts/deploy_web.sh
apps/web/               interfaz Jaspr: acceso, armario, ficha de prenda y perfil + pruebas de navegador en apps/web/e2e
packages/core/          Dart puro: modelos, reglas, contratos de repositorio, textos es, WardrobeBloc (bloc, no flutter_bloc)
packages/supabase_data/ consultas a Supabase (armario y perfil) sobre el paquete `supabase`; las usan móvil y web
supabase/ services/ functions/ firebase.json …   backend y despliegues existentes, sin cambios de tecnología
```
`packages/core` no importa Flutter, `dart:ui`, `dart:io` ni plugins, y sólo depende de `bloc`, `equatable` y `uuid`
(lo comprueban `packages/core/test/portability_test.dart` y la lista de dependencias).

## Versiones
Flutter **3.47.1** / Dart 3.13.1 (`.fvmrc`) · Jaspr CLI **0.23.4** (`dart pub global activate jaspr_cli 0.23.4`, con
`~/.pub-cache/bin` en el PATH) · `build_web_compilers` fijo en **4.8.5** · `lints ^5` (alineado con `flutter_lints ^5`) · Node ≥ 20
(probado 24) · Google Chrome del sistema para las pruebas de navegador.

## Comandos verificados
```bash
cd ~/projects/AI-Fit
fvm flutter pub get                                   # una vez, en la raíz (workspace)
(cd packages/core && fvm dart test)                   # 15 pruebas (BLoC de armario, mapeo Supabase, categorías, portabilidad)
(cd packages/supabase_data && fvm dart test)          # 9 pruebas a nivel HTTP (filtros, orden, borrado en dos pasos, errores)
(cd apps/web && fvm dart test)                        # 10 pruebas (controlador de acceso, resolutor de imágenes)
(cd apps/mobile && fvm flutter analyze && fvm flutter test)   # 1 aviso de estilo; 42 pasan y 2 FALLAN YA EN LA BASE (ver abajo)
scripts/e2e_web.sh                                    # compila 2 variantes, levanta el simulado de Supabase y corre 16 pruebas de navegador
```
Fallos **previos** (idénticos en `main`): `apps/mobile/test/smoke_test.dart` espera `TASK: GENERATE_NEW_OUTFIT_PHOTO` y
`single one-piece garment` en el prompt de try-on y el prompt actual dice otra cosa. No se tocaron.

## Configuración (pública) y preview
`env.json` en la raíz (ignorado por Git; plantilla `env.example.json`) con `SUPABASE_URL` y `SUPABASE_PUBLISHABLE_KEY`; es el mismo
archivo que usa `scripts/build_testflight.sh`. La llave «publishable» va al navegador por diseño: la seguridad la dan las políticas RLS.
```bash
scripts/preview_web.sh start     # jaspr build con esos defines + servidor estático con gzip, en segundo plano, puerto 7702 (127.0.0.1)
scripts/preview_web.sh status    # rama y SHA del build servido
scripts/preview_web.sh stop      # los procesos no persisten tras reiniciar el servidor (no hay servicio configurado)
```
Sin `env.json` la web muestra «Falta configurar Supabase» (probado). **No se probó contra el proyecto real de Supabase ni contra Google:**
no hay credenciales en el servidor. Lo que sí se verificó es el cliente real (GoTrue/PostgREST/Storage de `supabase`) contra un
simulado local del protocolo (`apps/web/e2e/mock_supabase.mjs`: PKCE verificado con S256, RLS básica, URLs firmadas).

**Para validar el acceso real:** en Supabase → Authentication → URL Configuration → *Redirect URLs*, añadir cada origen desde el que
se abra la web: `http://localhost:7702` (túnel SSH) y, si se habilita, `https://hpmeserver.tail23f765.ts.net:7702`. El callback de
Google (`https://<proyecto>.supabase.co/auth/v1/callback`) no cambia.

## Mac y teléfonos
- Mac: `ssh -N -L 7702:127.0.0.1:7702 armando@100.121.183.5` y abrir `http://localhost:7702` (no `127.0.0.1` si Supabase sólo permite localhost).
- iPhone/Android: un túnel en `localhost` de la Mac no sirve; hace falta un hostname HTTPS alcanzable por el teléfono. Opción
  compatible con este host (teléfono en la tailnet): `tailscale serve --bg --https=7702 http://127.0.0.1:7702`. **No está configurado**
  (cambia la configuración de Tailscale del host) y requiere registrar el origen en Supabase como arriba.
- Sincronizar: `git fetch origin && git switch migration/jaspr-server-20261026`; `fvm flutter pub get` en la raíz y
  `cd apps/mobile && fvm flutter run -d <dispositivo>`. Un cambio sólo en un widget Flutter no aparece en la web, y la web no tiene
  hot reload de Flutter: tras editar, `scripts/preview_web.sh start` y recargar.

## Qué se prueba dónde
| En el servidor / navegador | Necesita credenciales, dispositivo real o Mac |
| --- | --- |
| Reglas del core, consultas HTTP, controlador de acceso, build Jaspr, flujo completo contra el simulado, accesibilidad, rendimiento | Google + proyecto Supabase reales; `ai-router`/image-worker (alta de prendas, looks, try-on); Apple Vision; iOS (`pod install`, firma, TestFlight); Safari iPhone y Chrome Android reales |

## Android
**Fuera de alcance, decisión del 2026-10-26.** AI-Fit está pensada para iOS (Apple Vision para el recorte, firma/TestFlight en la Mac), así que
no se mantiene Android en el servidor. El proyecto Android nunca se construyó con Flutter 3.47.1: pide Gradle ≥ 8.14 y AGP ≥ 8.11.1
(tiene 8.12 / 8.9.1). Un intento de subir versiones quedó guardado como parche sin aplicar en `~/projects/.logs/aifit-android-wip.patch`
(no verificado, no hay APK). Para probar en móvil, usar la web Jaspr (preview) o iOS desde la Mac.
