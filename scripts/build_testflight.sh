#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ ! -f env.json ]]; then
  echo "Falta env.json. Créalo desde env.example.json y completa sus dart-defines." >&2
  exit 1
fi

exec fvm flutter build ipa --release --dart-define-from-file=env.json "$@"
