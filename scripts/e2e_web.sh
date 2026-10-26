#!/usr/bin/env bash
# Pruebas de navegador de apps/web contra un servidor SIMULADO del protocolo de Supabase (sin credenciales ni producción).
# Compila dos variantes (sin configuración y apuntando al simulado), las sirve y ejecuta apps/web/e2e.
#   scripts/e2e_web.sh                 # requiere: jaspr, node, Google Chrome; y `npm install` en apps/web/e2e
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB_DIR="$ROOT_DIR/apps/web"; E2E_DIR="$WEB_DIR/e2e"; RUN_DIR="${RUN_DIR:-$HOME/projects/.run}"
export PATH="$HOME/.pub-cache/bin:$PATH"; mkdir -p "$RUN_DIR"
MOCK_PORT="${MOCK_PORT:-7712}"; APP_PORT="${APP_PORT:-7722}"; BARE_PORT="${BARE_PORT:-7723}"
pids=(); cleanup() { for p in "${pids[@]}"; do kill "$p" 2>/dev/null || true; done; }; trap cleanup EXIT

echo "==> build sin configuración"; (cd "$WEB_DIR" && jaspr build >/dev/null) && rm -rf "$WEB_DIR/build/bare" && cp -r "$WEB_DIR/build/jaspr" "$WEB_DIR/build/bare"
echo "==> build contra el simulado (http://127.0.0.1:$MOCK_PORT)"
(cd "$WEB_DIR" && jaspr build --dart-define=SUPABASE_URL="http://127.0.0.1:$MOCK_PORT" --dart-define=SUPABASE_PUBLISHABLE_KEY=clave-publica-de-prueba >/dev/null)
PORT=$MOCK_PORT node "$E2E_DIR/mock_supabase.mjs" >"$RUN_DIR/aifit-mock.log" 2>&1 & pids+=($!)
ROOT="$WEB_DIR/build/jaspr" PORT=$APP_PORT node "$ROOT_DIR/scripts/static_spa.mjs" >"$RUN_DIR/aifit-e2e-app.log" 2>&1 & pids+=($!)
ROOT="$WEB_DIR/build/bare" PORT=$BARE_PORT node "$ROOT_DIR/scripts/static_spa.mjs" >"$RUN_DIR/aifit-e2e-bare.log" 2>&1 & pids+=($!)
sleep 1
cd "$E2E_DIR" && MOCK_URL="http://127.0.0.1:$MOCK_PORT" APP_URL="http://127.0.0.1:$APP_PORT" BARE_URL="http://127.0.0.1:$BARE_PORT" npm test
