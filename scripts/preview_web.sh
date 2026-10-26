#!/usr/bin/env bash
# Preview de la interfaz Jaspr (apps/web) desde un servidor Linux. Sin hot reload de Flutter.
#   scripts/preview_web.sh build | start | status | stop
# Configuración (pública, va al navegador): env.json en la raíz (el mismo que usa la app móvil con
# --dart-define-from-file) o las variables SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY. Sin ellas la web
# compila y muestra «Falta configurar Supabase».
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WEB_DIR="$ROOT_DIR/apps/web"; OUT_DIR="$WEB_DIR/build/jaspr"
RUN_DIR="${RUN_DIR:-$HOME/projects/.run}"; PORT="${PORT:-7702}"; PID="$RUN_DIR/aifit-web.pid"
export PATH="$HOME/.pub-cache/bin:$PATH"
mkdir -p "$RUN_DIR"
alive() { [[ -f "$PID" ]] && kill -0 "$(cat "$PID")" 2>/dev/null; }

defines() { # KEY=VALUE por línea: env.json o variables de entorno (sólo las claves públicas que la web usa)
  python3 - "$ROOT_DIR/env.json" <<'PY'
import json, os, sys
data = {}
try: data = json.load(open(sys.argv[1]))
except OSError: pass
for k in ("SUPABASE_URL", "SUPABASE_PUBLISHABLE_KEY"):
    v = os.environ.get(k) or data.get(k) or ""
    if v and "TU_" not in v: print(f"{k}={v}")
PY
}

build() {
  command -v jaspr >/dev/null || { echo "Falta jaspr: dart pub global activate jaspr_cli 0.23.4" >&2; exit 1; }
  local args=() n=0
  while IFS= read -r line; do args+=("--dart-define=$line"); n=$((n+1)); done < <(defines)
  [[ $n -lt 2 ]] && echo "⚠️  Sin SUPABASE_URL/SUPABASE_PUBLISHABLE_KEY: la web mostrará «Falta configurar Supabase»." >&2
  (cd "$WEB_DIR" && jaspr build "${args[@]}")
  printf '%s %s\n' "$(git -C "$ROOT_DIR" branch --show-current)" "$(git -C "$ROOT_DIR" rev-parse --short HEAD)" > "$OUT_DIR/preview-version.txt"
}
stop() { alive && kill "$(cat "$PID")" 2>/dev/null || true; rm -f "$PID"; [[ "${1:-}" == quiet ]] || echo "Preview detenido."; }
status() {
  alive || { echo "Preview detenido."; return 1; }
  echo "Preview activo: http://127.0.0.1:$PORT (HTTP $(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/")) · $(cat "$OUT_DIR/preview-version.txt" 2>/dev/null)"
}
case "${1:-}" in
  build) build ;;
  start) stop quiet; build
         ss -ltn "sport = :$PORT" 2>/dev/null | grep -q LISTEN && { echo "Puerto $PORT ocupado" >&2; exit 1; }
         ROOT="$OUT_DIR" PORT="$PORT" setsid nohup node "$ROOT_DIR/scripts/static_spa.mjs" >"$RUN_DIR/aifit-web.log" 2>&1 &
         echo $! > "$PID"; sleep 1; status ;;
  stop) stop ;;
  status) status ;;
  *) sed -n '2,4p' "$0"; exit 1 ;;
esac
