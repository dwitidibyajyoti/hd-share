#!/bin/bash
set -e

# Read version from Info.plist or use argument if provided
PLIST_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist 2>/dev/null || echo "1.1.0")
VERSION="${1:-$PLIST_VERSION}"

# Normalize version tag format (e.g., v1.1.0)
if [[ ! "$VERSION" =~ ^v ]]; then
    VERSION_TAG="v$VERSION"
else
    VERSION_TAG="$VERSION"
fi

echo "🚀 Starting Production Build & DMG Creation for HDShare ($VERSION_TAG)..."

# Step 1: Run the release build
./build_app.sh

APP_BUNDLE="build/HDShare.app"
DMG_NAME="HDShare-${VERSION_TAG}.dmg"
DMG_PATH="build/$DMG_NAME"
VOLUME_NAME="HDShare"
STAGING_DIR="build/dmg_staging"

if [ ! -d "$APP_BUNDLE" ]; then
    echo "❌ Error: $APP_BUNDLE not found. Build failed."
    exit 1
fi

echo "🧹 Preparing DMG staging directory..."
rm -rf "$STAGING_DIR" "$DMG_PATH"
mkdir -p "$STAGING_DIR"

# Copy the app bundle into staging
cp -R "$APP_BUNDLE" "$STAGING_DIR/HDShare.app"

# Create symlink to /Applications for drag-and-drop installer experience
ln -s /Applications "$STAGING_DIR/Applications"

echo "💿 Creating compressed DMG ($DMG_NAME)..."
hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# Clean up staging folder
rm -rf "$STAGING_DIR"

echo "✅ Success! Production DMG created at: $DMG_PATH"
ls -lh "$DMG_PATH"
