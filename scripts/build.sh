#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p "$ROOT/.build/module-cache" "$ROOT/.build/swiftpm-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/.build/module-cache"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/module-cache"
export SWIFTPM_CACHE_PATH="$ROOT/.build/swiftpm-cache"
swift build -c release --arch arm64
BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path)"
APP="$ROOT/build/MD Peek.app"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN_DIR/MDPeek" "$APP/Contents/MacOS/MDPeek"
cp Info.plist "$APP/Contents/Info.plist"
plutil -lint "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
echo "Built $APP"
