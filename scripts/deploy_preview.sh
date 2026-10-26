#!/usr/bin/env bash
# Publica la interfaz Jaspr (apps/web) en un CANAL DE VISTA PREVIA de Firebase Hosting, con URL temporal (7 días).
# No toca el sitio en producción. Uso:  scripts/deploy_preview.sh [nombre-del-canal]
# Requiere una sola vez:  firebase login --no-localhost   (como armando, en el servidor)
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="aifit-a7f6b"
CHANNEL="${1:-$(git -C "$ROOT_DIR" branch --show-current | tr -c 'a-zA-Z0-9\n' '-' | cut -c1-40)}"
source "$HOME/server/infra/dev-env.sh" >/dev/null 2>&1 || true
firebase login:list 2>&1 | grep -q "Logged in" || { echo "Falta iniciar sesión: firebase login --no-localhost" >&2; exit 1; }
"$ROOT_DIR/scripts/preview_web.sh" build
cd "$ROOT_DIR"
firebase --config firebase.jaspr.json --project "$PROJECT" hosting:channel:deploy "$CHANNEL" --expires 7d
