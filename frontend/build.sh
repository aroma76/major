#!/bin/bash
set -e

echo "=== Flutter Web Build for Vercel ==="

# ── Download Flutter SDK (tarball from Google CDN — no git clone needed) ──────
if [ ! -d "flutter/bin" ]; then
  echo "Resolving latest stable Flutter release..."

  # Use Python3 to parse the releases JSON reliably (no fragile grep/sed)
  FLUTTER_URL=$(python3 - <<'PYEOF'
import urllib.request, json, sys
url = "https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json"
try:
    with urllib.request.urlopen(url, timeout=30) as r:
        data = json.loads(r.read())
    stable_hash = data["current_release"]["stable"]
    base = "https://storage.googleapis.com/flutter_infra_release/releases/"
    for release in data["releases"]:
        if release["hash"] == stable_hash:
            print(base + release["archive"])
            sys.exit(0)
    sys.exit(1)
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
)

  echo "Downloading Flutter from: $FLUTTER_URL"
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
