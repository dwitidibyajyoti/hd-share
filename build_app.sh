#!/bin/bash
set -e

echo "🔨 Building HDShare in release mode..."
swift build -c release

APP_DIR="build/HDShare.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "📦 Packaging $APP_DIR..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy main executable
cp .build/release/HDShare "$MACOS_DIR/HDShare"

# Copy Info.plist
cp Resources/Info.plist "$CONTENTS_DIR/Info.plist"

# Generate or copy AppIcon.icns
if [ ! -f "Resources/AppIcon.icns" ]; then
    echo "🎨 Generating AppIcon.icns..."
    swift - << 'EOF'
import AppKit

let sizes = [16, 32, 128, 256, 512]
let iconsetPath = "Resources/AppIcon.iconset"
let fm = FileManager.default
try? fm.removeItem(atPath: iconsetPath)
try? fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

for size in sizes {
    for scale in [1, 2] {
        let pixelSize = size * scale
        let img = NSImage(size: NSSize(width: pixelSize, height: pixelSize))
        img.lockFocus()
        
        let rect = NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
        let cornerRadius = CGFloat(pixelSize) * 0.223
        let roundedRect = rect.insetBy(dx: CGFloat(pixelSize) * 0.05, dy: CGFloat(pixelSize) * 0.05)
        let path = NSBezierPath(roundedRect: roundedRect, xRadius: cornerRadius, yRadius: cornerRadius)
        
        let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.32, alpha: 1.0),
            NSColor(calibratedRed: 0.05, green: 0.50, blue: 0.90, alpha: 1.0)
        ])!
        gradient.draw(in: path, angle: -45)
        
        NSColor(white: 1.0, alpha: 0.25).setStroke()
        path.lineWidth = CGFloat(pixelSize) * 0.015
        path.stroke()
        
        let config = NSImage.SymbolConfiguration(pointSize: CGFloat(pixelSize) * 0.44, weight: .bold)
        if let symbol = NSImage(systemSymbolName: "video.badge.waveform", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
            let symbolRect = NSRect(
                x: (CGFloat(pixelSize) - symbol.size.width) / 2.0,
                y: (CGFloat(pixelSize) - symbol.size.height) / 2.0,
                width: symbol.size.width,
                height: symbol.size.height
            )
            symbol.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
        img.unlockFocus()
        
        if let tiff = img.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiff),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            let filename = scale == 1 ? "icon_\(size)x\(size).png" : "icon_\(size)x\(size)@2x.png"
            try? pngData.write(to: URL(fileURLWithPath: "\(iconsetPath)/\(filename)"))
        }
    }
}
EOF
    iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns 2>/dev/null || true
    rm -rf Resources/AppIcon.iconset
fi

if [ -f "Resources/AppIcon.icns" ]; then
    echo "📦 Bundling AppIcon.icns..."
    cp "Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi

# Bundle static FFmpeg binary into Resources
FFMPEG_SRC=""
if [ -f "Resources/ffmpeg" ]; then
    FFMPEG_SRC="Resources/ffmpeg"
elif [ -f "/opt/homebrew/bin/ffmpeg" ]; then
    FFMPEG_SRC="/opt/homebrew/bin/ffmpeg"
elif [ -f "/usr/local/bin/ffmpeg" ]; then
    FFMPEG_SRC="/usr/local/bin/ffmpeg"
elif command -v ffmpeg >/dev/null 2>&1; then
    FFMPEG_SRC="$(command -v ffmpeg)"
fi

if [ -n "$FFMPEG_SRC" ]; then
    echo "📦 Bundling FFmpeg ($FFMPEG_SRC) into App Resources..."
    cp "$FFMPEG_SRC" "$RESOURCES_DIR/ffmpeg"
    chmod +x "$RESOURCES_DIR/ffmpeg"
else
    echo "⚠️ Warning: FFmpeg binary not found to bundle directly. Will attempt to use system FFmpeg at runtime."
fi

# Ad-hoc code sign for macOS (deep sign includes bundled binaries)
echo "✍️  Applying ad-hoc code signature..."
codesign --force --deep --sign - "$APP_DIR"

echo "✅ App bundle created successfully at $APP_DIR"

