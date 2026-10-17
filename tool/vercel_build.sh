#!/usr/bin/env bash
# Vercel's build step for the student web app (vercel.json): installs Flutter, then builds build/web.
# Vercel has no Flutter, so a pinned release is fetched into .flutter (kept in Vercel's build cache).
# Project environment variables: BACKEND_URL (default the Render server), FCM_VAPID_KEY (optional).
set -euo pipefail

FLUTTER_VERSION=3.38.10 # Dart 3.10, as pubspec.yaml's sdk constraint

command -v unzip >/dev/null || dnf install -y -q unzip xz >/dev/null

if [ "$(cat .flutter/version 2>/dev/null || true)" != "$FLUTTER_VERSION" ]; then
  rm -rf .flutter
  curl -fsSL "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" | tar -xJ
  mv flutter .flutter
fi
git config --global --add safe.directory "$PWD/.flutter"
export PATH="$PWD/.flutter/bin:$PATH"
flutter config --no-analytics >/dev/null
flutter --version

defines=(--dart-define=BACKEND_URL="${BACKEND_URL:-https://konduct-backend.onrender.com}")
if [ -n "${FCM_VAPID_KEY:-}" ]; then defines+=(--dart-define=FCM_VAPID_KEY="$FCM_VAPID_KEY"); fi

flutter pub get
flutter build web --release --no-source-maps "${defines[@]}"
# Flutter's own offline-first worker is replaced by web/sw.js.
rm -f build/web/flutter_service_worker.js
