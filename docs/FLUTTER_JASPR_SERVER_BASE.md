# Base Flutter + Jaspr y desarrollo desde servidor

## Aplicación de esta guía a AI-Fit

App actual en la raíz (`pubspec.yaml`, `lib/`), con `bloc`, `flutter_bloc`, GetIt, Dio, `supabase_flutter`, Google Sign-In, image picker y servicios nativos de recorte. Backend existente en `supabase/`, `services/image-worker/` y `functions/`: mantenerlos y sus despliegues.

Empezar con consulta de armario y perfil, después de cerrar login. `lib/features/auth/data/auth_repository.dart` mezcla Supabase, GoogleSignIn y condiciones `kIsWeb`; no trasladarlo intacto al core. Separar modelo/reglas de perfil de las implementaciones de login y persistencia. `lib/core/services/apple_vision_background_removal_service.dart` y `native_cutout_service.dart` quedan nativos; Jaspr necesita alternativa explícita para carga/recorte y no puede ejecutar Apple Vision. Reutilizar `lib/core/interfaces/ai_service.dart` si su contrato sigue siendo portable. Los flujos de generación/try-on deben conservar estados de espera, errores y límites del backend sin duplicarlos. No migrar el worker de imágenes a Dart como parte del cambio de frontend.

## Objetivo y alcance

Base para una migración posterior, revisada el 26 de octubre de 2026. Hoy sólo se documenta: no se mueven carpetas, no se cambia la UI y no se despliega. «Monolito» aquí significa **monorepo con dos interfaces y lógica Dart compartida**; no obliga a fusionar backends ni a ejecutar código nativo en el navegador. El framework web es **Jaspr**.

El agente del servidor editará una rama propia; podrás revisar el resultado web desde la Mac, iPhone o Android. La web reflejará cambios de su interfaz Jaspr y del núcleo compartido. Un cambio exclusivo de un widget Flutter no aparecerá automáticamente en Jaspr: ambas presentaciones se implementan y prueban por separado.

## Referencia comprobada: frontend_app_jaspr

Repositorio `frontend_app_flutter` en AWS CodeCommit, carpeta local `frontend_app_jaspr`. Referencia del código inspeccionado: commit `e8294e6c825efc71cd43cde808c36819aaf59cb0` más cambios locales de la rama `refreshToken` preservados durante esta sincronización. No usar `master` como si contuviera necesariamente este mismo estado.

| Pieza real | Papel y límite |
| --- | --- |
| `pubspec.yaml` | Pub workspace: `packages/core`, `apps/mobile`, `apps/web`, `qa`, `qa/ios_app`. |
| `packages/core/pubspec.yaml` | Dart compartido, sin dependencia del SDK Flutter: `bloc`, `dio`, modelos y repositorios. |
| `apps/mobile` | Flutter nativo; conserva plugins, navegación, widgets y servicios de plataforma. |
| `apps/web` | Componentes Jaspr, HTML/CSS y adaptadores del navegador; consume el mismo core. |
| `apps/web/lib/main.client.dart` | Composition root web: inyecta DioClient, repositorios y almacenamiento web mediante GetIt. |
| `apps/web/lib/app.dart` | Gate de sesión y presentación Jaspr; no reutiliza el árbol de widgets Flutter. |
| `scripts/run_web.sh` | Jaspr interno en 7676 y BFF visible en 7675; carga `config/settings.json`, ignorado por Git. |
| `scripts/local_bff.mjs` | Proxy de desarrollo con rutas de sesión; mantener el origen de frontend y sesión consistente. |
| `.fvmrc`, `scripts/flutterw` | Flutter fijado a 3.47.1 en esta referencia; verificar SDK efectivo antes de ejecutar. |
| `apps/web/pubspec.yaml` | Jaspr `^0.23.4`, modo `client`, Dart `^3.10.0`. Son versiones observadas, no una orden de actualizar otros proyectos. |
| `apps/web/web/index.html` | Arranque manual con `app.mjs` y `app.wasm`; no asumir que el build estándar genera exactamente esos nombres. |

Documentos de referencia versionados: `docs/flutter_web_retirement_2026_09_24.md` y `docs/perf/jaspr_migration_status_2026_09_24.md`. El primero retiró Flutter Web/WASM de la app móvil, sus switches y puentes antiguos; el segundo registra paridad y pendientes históricos. Revisar de nuevo el código al migrar: estos informes no certifican el estado actual de todas las funcionalidades. No copiar los antiguos scripts `switch_to_*`, ni importar `flutter_bloc`, `dart:ui`, `dart:io` o plugins Flutter desde el core/web.

El retiro de **Flutter Web** no significa prohibir **Dart compilado a Wasm** en Jaspr: son decisiones distintas. La referencia mezcla un HTML de arranque Wasm y scripts de Jaspr; antes de copiar el pipeline, comprobar el artefacto real y elegir explícitamente JS o Wasm con compatibilidad de navegador y tiempos medidos.

## Estructura de destino

```text
pubspec.yaml                 # workspace, sin convertirlo en app Flutter
pubspec.lock                 # resolución única, versionada
apps/mobile/                 # aplicación Flutter original
apps/web/                    # interfaz HTML/CSS en Jaspr
packages/core/               # Dart compartido, sin Flutter ni APIs de plataforma
packages/<plugin_existente>/ # conservar si el proyecto ya tiene uno
scripts/                     # reutilizar comandos existentes; añadir sólo lo necesario
docs/                        # paridad, decisiones y evidencia
<backend_existente>/         # conservar su tecnología y despliegue
```

No crear paquetes vacíos para satisfacer el dibujo. El primer core contiene únicamente lógica que realmente usarán ambos clientes. Modelos, validaciones, serialización, reglas de negocio y repositorios aptos para navegador pueden compartirse; widgets, `BuildContext`, archivos locales, Keychain, MethodChannels, Firebase Messaging nativo y cámara quedan en adaptadores. Reutilizar las interfaces existentes antes de inventar nuevas. Un Cubit es compartible sólo si usa `bloc` puro y sus dependencias son portables; `flutter_bloc` permanece en mobile. Conservar el gestor de estado del proyecto, incluido Riverpod donde ya se use.

La configuración raíz declara `workspace: [packages/core, apps/mobile, apps/web]`; cada miembro declara `resolution: workspace`. Los workspaces requieren Dart >=3.6; verificar además el requisito real de Jaspr, del SDK Flutter elegido y de cada dependencia. No fijar sólo la cota mínima del workspace si las dependencias requieren un Dart más nuevo. Cada miembro lleva un nombre único y la app declara dependencia del core. Resolver con `flutter pub get` desde la raíz cuando el workspace incluya Flutter. Versionar el lockfile raíz y verificar cómo se trasladan los locks anteriores. Fuente: [Pub workspaces](https://dart.dev/tools/pub/workspaces).

## Migración por entregas pequeñas

1. **Baseline recuperable.** Rama y commit exactos, tests/análisis existentes, flujos críticos, capturas y mediciones. Inventariar plugins, secretos, callbacks OAuth, assets, identificadores de aplicación, firma, CI y rutas. No cambiar SDK y arquitectura a la vez.
2. **Mover sin cambiar comportamiento.** Trasladar app a `apps/mobile` con historial (`git mv`); corregir rutas de assets, dependencias `path`, scripts, CI, Firebase, Gradle, Xcode, Pods y firma. Compilar y probar el móvil antes de introducir Jaspr. Mantener backends y plugins existentes.
3. **Extraer lo reutilizable.** Un flujo completo de modelos → repositorio → estado, con prueba de contrato y adaptadores de almacenamiento/autenticación. Evitar copiar lógica entre clientes. No poner secretos ni plugins en el core.
4. **Primera vertical Jaspr.** Login y una función útil con datos controlados; cubrir carga, vacío, error, permisos, expiración y logout. Presentación accesible con HTML semántico, CSS responsive y teclado. Probar recarga directa y navegación atrás.
5. **Paridad por pantalla.** Tabla Flutter/Jaspr con comportamiento, datos, adjuntos, rutas, dispositivos y evidencia. Marcar claramente lo sólo nativo y cualquier simulación. La web no sustituye una prueba de cámara, notificaciones, iCloud o plugins.
6. **Preview y aceptación.** Publicar sólo entorno de revisión, medir build optimizado y aprobar la vertical en móvil y web. Repetir con la siguiente función. Retirar Flutter Web anterior únicamente cuando se haya aceptado la cobertura requerida.

## Servidor → navegador → teléfono

Propuesta inicial, pendiente de conocer sistema operativo, arquitectura CPU, memoria, dirección de red y dominio del servidor: el servidor ejecuta agente, Git, tests Dart/Flutter y previews Jaspr; la Mac conserva Xcode, firma e iPhone. Android puede construirse en un servidor compatible con Android SDK y JDK. Preferir una sola rama y worktree por agente/tarea, con puertos y dependencias separados.

| Vista que quieres revisar | Flujo |
| --- | --- |
| Web en Safari/Chrome, también desde teléfono | Agente edita core/Jaspr → compilación de desarrollo o build de preview → navegador recarga. No requiere instalar una app nativa. |
| Android nativo con hot reload | App debug y sesión `flutter run` en la máquina que tiene conectado el dispositivo por USB o ADB Wi-Fi. Tras editar, enviar `r`; `R` reinicia estado. |
| iPhone nativo con hot reload | Checkout actualizado en la Mac, Xcode y firma configurados, iPhone emparejado y sesión Flutter debug activa. Agente puede trabajar en servidor; código y sesión de depuración deben converger en ese checkout de Mac. |
| App instalada fuera de una sesión debug | Nuevo APK para Android o build firmado/TestFlight para iOS. Un push a Git no actualiza por sí solo una app instalada. |

[Hot reload de Flutter](https://docs.flutter.dev/tools/hot-reload) conserva estado en debug y no vuelve a ejecutar `main()`/`initState()`; cambios nativos exigen reconstrucción. [iOS requiere el entorno Xcode](https://docs.flutter.dev/platform-integration/ios/setup); configurar confianza, modo de desarrollador, firma y permiso de red local. No asumir que un servidor Linux puede compilar iOS. [ADB Wi-Fi](https://developer.android.com/tools/adb) requiere emparejamiento y red alcanzable; probar primero en la misma LAN, sin exponer el depurador a Internet. Una VPN no garantiza descubrimiento mDNS.

Para empezar sin cambiar la red del servidor, usar desde la Mac un túnel SSH al preview ya levantado en el servidor:

```bash
# En la Mac, sustituir usuario y host; puerto 7675 es el de la referencia.
ssh -N -L 7675:127.0.0.1:7675 usuario@servidor
# Abrir http://localhost:7675 en la Mac.
```

Esto no hace que `localhost` del iPhone apunte al servidor ni a la Mac. Para teléfonos, crear después un hostname HTTPS de preview accesible por LAN/VPN o un proxy autenticado. Mantener mismo origen para sesión y frontend, registrar exactamente callbacks/logout/orígenes en OAuth y verificar cookies Secure/SameSite, CORS y CSRF. Configurar soporte de WebSocket si se quiere recarga automática. El BFF local actual contiene orígenes `localhost` y no ofrece garantía de proxy del canal de recarga: probar autenticación y recarga; usar actualización manual mientras se valida. No presentar el script local como un servicio público listo para producción.

Flujo Git para cada tarea: agente crea rama desde una base publicada, trabaja, ejecuta checks, hace commit y push; el preview registra rama y SHA visibles. La Mac hace fetch y revisa esa rama antes de ejecutar móvil. Para ciclo corto, puede recibir archivos en **un checkout de preview dedicado** y lanzar hot reload después; nunca sincronizar indiscriminadamente encima del checkout con trabajo humano. Si ambos editan la misma rama, hacer commit, fetch y merge antes de publicar. No usar `push --force`, `reset --hard` ni mezclar ramas funcionales sólo para trasladar el entorno.

## Ejecutar la referencia y preparar el servidor

Estos comandos son del monorepo de referencia; en los otros proyectos sólo aplicarán después de implementar la migración:

```bash
# En la raíz de frontend_app_jaspr, con el SDK fijado instalado:
scripts/flutterw --version
scripts/flutterw pub get
# Preparar config/settings.json desde config/settings.template.json por canal seguro.
scripts/run_web.sh
# En otra terminal, después de conectar un dispositivo:
scripts/run_mobile.sh -d ID_DISPOSITIVO
```

Confirmar la interfaz de los scripts de la rama antes de usarlos. En otro proyecto, conservar su SDK/FVM y sus comandos hasta completar la fase 2. Clonar usando las URLs reales del informe de sincronización; para CodeCommit, instalar Git y configurar credenciales AWS con acceso al repositorio. No copiar la carpeta `.git` entre Mac y servidor ni usar `git push --mirror`.

Instalar en el servidor versiones compatibles de Dart/Flutter (FVM cuando exista), Git, Node y Jaspr CLI compatibles con el lockfile. Validar arquitectura de binarios y licencias del SDK Android cuando corresponda. Transferir aparte `.env`, `config/settings.json`, Firebase, claves de firma y credenciales AWS mediante un canal seguro y con permisos restringidos. No incluirlos en imágenes, logs o Markdown. `--dart-define` incorporado al navegador o móvil es configuración pública, no un almacén de secretos.

El deploy de la referencia usa `sed -i ''` específico de macOS y Firebase Hosting: no ejecutarlo sin adaptar y revisar su destino en Linux. Un sitio Jaspr `client` puede servir `build/jaspr` como archivos estáticos, pero necesita que sus servicios de sesión/API sigan disponibles. Fuentes: [CLI Jaspr](https://docs.jaspr.site/dev/cli), [deploy Jaspr](https://docs.jaspr.site/dev/deploying). Para un preview estable, preferir build optimizado servido por HTTPS; reservar `jaspr serve` para desarrollo. No publicar producción durante esta preparación.

## Rendimiento y verificación de aceptación

Jaspr permite una interfaz DOM/CSS; el rendimiento depende de la implementación y debe medirse. Conservar resultados de la misma pantalla, datos, teléfono, red y modo release antes/después: bytes transferidos comprimidos, JS/Wasm inicial, primera vista útil, LCP/INP/CLS, tiempo de autenticación y de la interacción crítica. Fijar presupuestos a partir del baseline y fallar la entrega si hay regresiones sin justificación; no prometer ganancias sin medición. Evitar cargar SDKs, modelos, imágenes enormes o módulos completos antes de usarlos; paginar listas y usar tamaños de imagen apropiados. Separar tiempo de backend del renderizado.

Antes de cerrar cada vertical:

- Pruebas Dart del core y rechazo de imports/dependencias Flutter o plataforma en él, incluidos imports transitivos.
- Análisis y pruebas Flutter afectadas; build Android y build iOS en Mac cuando corresponda. Conservar comportamiento nativo y permisos.
- Análisis y build Jaspr; servir el directorio generado y comprobar que HTML solicita archivos que existen (especialmente JS/Wasm), con MIME correctos y rutas profundas resueltas.
- Smoke en Safari iPhone y Chrome Android: login, logout, recarga, atrás, estado vacío, errores, accesibilidad y permisos. Comprobar ausencia de tokens/PII en consola.
- Verificar sesión y backend reales con cuenta de prueba; mocks y previews no prueban producción.
- Medición de rendimiento con evidencia del SHA, navegador, dispositivo y configuración; rollback al commit anterior preparado.

## Encargo base para el siguiente agente

«Lee esta guía y la arquitectura actual. Entrega primero baseline, inventario de dependencias nativas y matriz de paridad. Trabaja en una rama nueva y conserva la app nativa. Aplica la estructura `apps/mobile`, `apps/web`, `packages/core` usando sólo lógica realmente compartida. Completa una primera vertical con pruebas, build móvil y Jaspr, preview con SHA y mediciones antes/después. No copies secretos, widgets Flutter ni scripts retirados de la referencia. No declares paridad de hardware a partir de una pantalla web. Publica tu rama para revisión; el despliegue a producción requiere una tarea explícita.»
