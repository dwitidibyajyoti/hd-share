#!/bin/bash
set -e

echo "🚀 Starting Production Build & DMG Creation for HDShare..."

# Step 1: Run the release build
./build_app.sh

APP_BUNDLE="build/HDShare.app"
DMG_NAME="HDShare-Installer.dmg"
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
