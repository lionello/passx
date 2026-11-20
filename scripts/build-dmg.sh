#!/bin/bash
# Builds passx.app (Release) and packages it into build/passx-<version>.dmg
#
# Optional environment:
#   SIGN_IDENTITY     codesign identity, e.g. "Developer ID Application" (default: "-" = ad-hoc)
#   NOTARY_APPLE_ID   Apple ID used for notarization      ┐
#   NOTARY_PASSWORD   app-specific password for that ID   ├ notarize + staple when all three are set
#   NOTARY_TEAM_ID    Apple Developer team ID             ┘
set -euo pipefail

cd "$(dirname "$0")/.."

BUILD_DIR=build
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
VERSION="$(git describe --tags --always --dirty)"
APP="$BUILD_DIR/DerivedData/Build/Products/Release/passx.app"
DMG="$BUILD_DIR/passx-${VERSION#v}.dmg"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Developer ID builds need a secure timestamp; ad-hoc signatures can't have one
SIGN_FLAGS=""
if [ "$SIGN_IDENTITY" != "-" ]; then
    SIGN_FLAGS="--timestamp"
fi

# Override the project's manual signing (which expects a provisioning profile that isn't needed for Developer ID)
xcodebuild build \
    -project passx.xcodeproj \
    -scheme passx \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    PROVISIONING_PROFILE_SPECIFIER="" \
    OTHER_CODE_SIGN_FLAGS="$SIGN_FLAGS"

codesign --verify --deep --strict --verbose=2 "$APP"

# Stage the app next to an /Applications shortcut so users can drag-install
STAGING="$BUILD_DIR/dmg"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# hdiutil occasionally fails with "Resource busy" on CI runners, so retry a few times
for attempt in 1 2 3 4 5; do
    if hdiutil create -volname passx -srcfolder "$STAGING" -ov -format UDZO "$DMG"; then
        break
    fi
    if [ "$attempt" = 5 ]; then
        echo "hdiutil failed" >&2
        exit 1
    fi
    sleep 5
done

if [ "$SIGN_IDENTITY" != "-" ]; then
    codesign --sign "$SIGN_IDENTITY" --timestamp "$DMG"
fi

if [ -n "${NOTARY_APPLE_ID:-}" ] && [ -n "${NOTARY_PASSWORD:-}" ] && [ -n "${NOTARY_TEAM_ID:-}" ]; then
    xcrun notarytool submit "$DMG" \
        --apple-id "$NOTARY_APPLE_ID" \
        --password "$NOTARY_PASSWORD" \
        --team-id "$NOTARY_TEAM_ID" \
        --wait
    xcrun stapler staple "$DMG"
fi

echo "$DMG"
