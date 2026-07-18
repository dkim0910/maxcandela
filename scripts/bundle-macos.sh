#!/usr/bin/env bash
# Builds MaxCandela.app from the SwiftPM project and (optionally) a signed
# .pkg for Mac App Store upload.
#
# Usage:
#   scripts/bundle-macos.sh                  # ad-hoc signed .app (local testing)
#   SIGN_IDENTITY="Apple Distribution: …" \
#   INSTALLER_IDENTITY="3rd Party Mac Developer Installer: …" \
#   scripts/bundle-macos.sh --pkg            # App Store-ready .pkg
#
# App Store submission checklist (after this script):
#   1. App Store Connect: create the app (bundle ID com.maxcandela.MaxCandela)
#   2. Create IAPs: com.maxcandela.pro.lifetime ($9.99 non-consumable),
#      com.maxcandela.pro.monthly ($0.99 auto-renewable)
#   3. Upload: xcrun altool --upload-app -f dist/MaxCandela.pkg …
#      (or use Transporter.app)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MACOS_DIR="$REPO_ROOT/apps/macos"
DIST="$REPO_ROOT/dist"
APP="$DIST/MaxCandela.app"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"   # "-" = ad-hoc

echo "==> Building release binary (universal)…"
cd "$MACOS_DIR"
swift build -c release --arch arm64 --arch x86_64
BIN="$MACOS_DIR/.build/apple/Products/Release/MaxCandela"

echo "==> Generating icon…"
ICONSET="$DIST/AppIcon.iconset"
rm -rf "$ICONSET"
swift "$REPO_ROOT/scripts/make-icon.swift" "$ICONSET"
iconutil -c icns "$ICONSET" -o "$DIST/AppIcon.icns"

echo "==> Assembling ${APP}…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MaxCandela"
cp "$MACOS_DIR/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$DIST/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

echo "==> Codesigning (identity: $SIGN_IDENTITY)…"
codesign --force --options runtime \
    --entitlements "$MACOS_DIR/Resources/MaxCandela.entitlements" \
    --sign "$SIGN_IDENTITY" \
    "$APP"
codesign --verify --verbose=2 "$APP"

if [[ "${1:-}" == "--pkg" ]]; then
    : "${INSTALLER_IDENTITY:?Set INSTALLER_IDENTITY for --pkg (3rd Party Mac Developer Installer: …)}"
    echo "==> Building App Store package…"
    productbuild --component "$APP" /Applications \
        --sign "$INSTALLER_IDENTITY" \
        "$DIST/MaxCandela.pkg"
    echo "Done: $DIST/MaxCandela.pkg"
else
    echo "Done: $APP"
    echo "(Run with --pkg and signing identities for an App Store upload.)"
fi
