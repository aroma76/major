#!/bin/bash
set -e

echo "=== Flutter Web Build for Vercel ==="

# ── Download Flutter SDK (tarball from Google CDN — no git clone needed) ──────
if [ ! -d "flutter/bin" ]; then
  echo "Downloading Flutter 3.41.9 (pinned — 3.44.0 breaks flutter_feather_icons)..."
  FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.41.9-stable.tar.xz"
  curl -L --progress-bar "$FLUTTER_URL" -o flutter.tar.xz
  tar xf flutter.tar.xz
  rm flutter.tar.xz
  echo "Flutter SDK downloaded successfully."
else
  echo "Flutter SDK already present, skipping download."
fi

# ── Fix git safe.directory (Vercel runs as root — git rejects extracted dirs) ─
git config --global --add safe.directory "$(pwd)/flutter"

# ── Setup ─────────────────────────────────────────────────────────────────────
export PATH="$PATH:$(pwd)/flutter/bin"
flutter config --no-analytics
flutter --version

# ── Build ─────────────────────────────────────────────────────────────────────
flutter pub get
flutter build web --release --no-tree-shake-icons

echo "=== Build complete! Output: build/web ==="
