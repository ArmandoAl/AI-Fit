# Guía para agentes

- Desarrollo en servidor (versiones, comandos, preview, túnel, simulado de Supabase): `docs/SERVER_DEVELOPMENT.md`.
- Paridad móvil ↔ web, lo no portado y por qué: `docs/web_parity.md`. Rendimiento: `docs/perf/README.md`. Guía de la migración: `docs/FLUTTER_JASPR_SERVER_BASE.md`.
- `packages/core` debe seguir siendo Dart puro (sólo `bloc`, `equatable`, `uuid`); hay una prueba que lo exige. `packages/supabase_data` usa el paquete `supabase`, nunca `supabase_flutter`.
- Mantener flutter_bloc/GetIt/GoRouter en `apps/mobile`; no compartir widgets con la web. No migrar el image-worker ni las funciones a Dart.
- No inventes resultados de IA ni credenciales; las pruebas usan datos sintéticos y el simulado de `apps/web/e2e`. No uses el proyecto real para probar operaciones con efectos.
- No versionar `env.json`, llaves ni keystores. Sin `push --force`; no fusionar ramas base.
