#!/usr/bin/env bash
# Build Flutter Web (WASM) and deploy to Firebase Hosting.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶ Building Flutter web (WASM, release)..."
(cd apps/mobile && flutter build web --wasm --release)

echo "▶ Deploying to Firebase Hosting (project: aifit-a7f6b)..."
firebase deploy --only hosting

echo "✅ Done. Open Firebase Console → Hosting for your live URL."
