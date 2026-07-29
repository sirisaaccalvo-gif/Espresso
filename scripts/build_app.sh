#!/usr/bin/env bash
#
# Builds Espresso and assembles a runnable, ad-hoc-signed Espresso.app bundle.
# Usage: scripts/build_app.sh [--debug]
#
set -euo pipefail

cd "$(dirname "$0")/.."

CONFIG="release"
if [ "${1:-}" = "--debug" ]; then CONFIG="debug"; fi

# Espresso is Apple Silicon-only; Intel Macs are not supported (building or running).
if [ "$(uname -m)" != "arm64" ]; then
  echo "error: Espresso is Apple Silicon-only (M1 or later). Intel Macs are not supported." >&2
  exit 1
fi
ARCH="arm64"

echo "==> swift build (-c $CONFIG, --arch $ARCH)"
swift build -c "$CONFIG" --arch "$ARCH"
# --arch changes the bin path (arm64-apple-macosx/…) — resolve it with the SAME
# flags as the build, or we'd copy a stale/wrong-arch binary.
BIN_DIR="$(swift build -c "$CONFIG" --arch "$ARCH" --show-bin-path)"
BIN="$BIN_DIR/Espresso"

APP="Espresso.app"
echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Espresso"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>Espresso</string>
    <key>CFBundleDisplayName</key>     <string>Espresso</string>
    <key>CFBundleIdentifier</key>      <string>com.isaaccalvo.Espresso</string>
    <key>CFBundleExecutable</key>      <string>Espresso</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundleVersion</key>         <string>1</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <key>LSUIElement</key>             <true/>
    <key>NSHighResolutionCapable</key> <true/>
    <key>NSPrincipalClass</key>        <string>NSApplication</string>
    <key>CFBundleIconFile</key>        <string>AppIcon</string>
</dict>
</plist>
PLIST

if [ -f "Resources/AppIcon.icns" ]; then
  cp "Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

# The arm64-only slice IS the Intel enforcement: an arm64-only app cannot launch
# on an Intel Mac (Rosetta only translates the other way). Exact match, so a
# stray universal (x86_64 arm64) binary fails loudly too.
echo "==> verifying Apple Silicon-only binary"
ARCHS="$(lipo -archs "$APP/Contents/MacOS/Espresso")"
if [ "$ARCHS" != "arm64" ]; then
  echo "error: expected an arm64-only binary, found slices: $ARCHS" >&2
  exit 1
fi

echo "==> ad-hoc code signing"
xattr -cr "$APP"   # strip extended attributes that would break codesign
codesign --force --deep --sign - "$APP"

echo "==> done: $(pwd)/$APP"
echo "    run with:  open '$(pwd)/$APP'"
