#!/bin/bash
set -e

echo "Starting Flutter Web build for Vercel..."

# ── Download Flutter SDK (tarball — much faster than git clone) ──────────────
if [ ! -d "flutter/bin" ]; then
  echo "Downloading Flutter SDK..."
  FLUTTER_JSON=$(curl -sS https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json)
  FLUTTER_ARCHIVE=$(echo "$FLUTTER_JSON" \
    | grep -o '"archive":"[^"]*stable[^"]*\.tar\.xz"' \
    | head -1 \
    | sed 's/"archive":"//;s/"//')
  curl -sS "https://storage.googleapis.com/flutter_infra_release/releases/$FLUTTER_ARCHIVE" -o flutter.tar.xz
  tar xf flutter.tar.xz
  rm flutter.tar.xz
  echo "Flutter SDK downloaded."
else
  echo "Flutter SDK already exists, skipping download."
fi

# ── Add Flutter to PATH ───────────────────────────────────────────────────────
export PATH="$PATH:$(pwd)/flutter/bin"

# ── Get dependencies ──────────────────────────────────────────────────────────
flutter pub get

# ── Build Flutter Web ─────────────────────────────────────────────────────────
flutter build web --release --no-tree-shake-icons

echo "Build completed successfully!"
