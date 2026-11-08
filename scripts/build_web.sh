#!/usr/bin/env bash
# All web artifacts use the same self-contained build, including CI releases.
set -euo pipefail
cd "$(dirname "$0")/.."
flutter build web --release --no-web-resources-cdn --pwa-strategy=none "$@"
flutter_sdk="${FLUTTER_ROOT:-$(python3 -c 'import pathlib, shutil; print(pathlib.Path(shutil.which("flutter")).resolve().parent.parent)')}"
python3 scripts/bundle_font_fallbacks.py "$flutter_sdk"
python3 scripts/build_offline_cache.py
