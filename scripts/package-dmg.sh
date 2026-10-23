#!/bin/bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DIST_DIR="${RAZER_OUTPUT_DIR:-$PROJECT_DIR/dist}"
APP="${RAZER_APP_PATH:-$DIST_DIR/RazerBatteryMenu.app}"
ARCH="${RAZER_ARCH:-$(uname -m)}"
DMG="${RAZER_DMG_PATH:-$DIST_DIR/RazerBatteryMenu-$ARCH.dmg}"

if [ ! -d "$APP" ]; then
    echo "Missing app bundle: $APP" >&2
    echo "Run bash scripts/build.sh first." >&2
    exit 1
fi

STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/RazerBatteryMenu-dmg.XXXXXX")"
cleanup() { rm -rf "$STAGING_DIR"; }
trap cleanup EXIT

mkdir -p "$(dirname "$DMG")"
ditto "$APP" "$STAGING_DIR/RazerBatteryMenu.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "RazerBatteryMenu" \
    -srcfolder "$STAGING_DIR" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -ov "$DMG"

if [ -n "${DMG_CODESIGN_IDENTITY:-}" ]; then
    codesign --force --timestamp --sign "$DMG_CODESIGN_IDENTITY" "$DMG"
fi

hdiutil verify "$DMG"
shasum -a 256 "$DMG"
echo "Built: $DMG"
