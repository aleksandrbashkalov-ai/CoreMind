#!/bin/bash
# CoreMind Release + DMG Builder
set -euo pipefail

APP_NAME="CoreMind"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION_SWIFT="$PROJECT_DIR/Sources/CoreMind/Utilities/Version.swift"
VERSION=$(grep "static let version" "$VERSION_SWIFT" | sed -E 's/.*"(.+)".*/\1/')
APP_BUNDLE="$PROJECT_DIR/build/$APP_NAME.app"
DMG_NAME="${APP_NAME}_${VERSION}.dmg"
DMG_PATH="$PROJECT_DIR/build/$DMG_NAME"
STAGING="/tmp/${APP_NAME}_dmg_staging"

echo "=========================================="
echo " CoreMind v${VERSION} — Release + DMG"
echo "=========================================="

# Step 1: Build universal binary
echo ""
echo "==> [1/5] Building universal binary (arm64 + x86_64)..."
cd "$PROJECT_DIR"
swift build -c release --arch arm64 --arch x86_64
BINARY="$PROJECT_DIR/.build/apple/Products/Release/$APP_NAME"

# Step 2: Create .app bundle
echo ""
echo "==> [2/5] Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Step 3: Generate icon
echo ""
echo "==> [3/5] Generating app icon..."
ICONSET="$PROJECT_DIR/build/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

echo "   Generating icon PNGs..."
for s in 16 32 64 128 256 512; do
    python3 -c "
import struct, zlib, sys
w, h = $s, $s
def chunk(ct, d):
    c = ct + d
    return struct.pack('>I', len(d)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)
raw = b''
for y in range(h):
    raw += b'\x00'
    for x in range(w):
        cx, cy = x - w//2, y - h//2
        r = min(w, h) * 0.42
        d = (cx*cx + cy*cy) ** 0.5
        if d < r:
            i = 1.0 - (d / r) * 0.25
            raw += struct.pack('BBB', min(255,int(110*i)), min(255,int(80*i)), min(255,int(200*i)))
        else:
            raw += b'\x00\x00\x00'
png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw)) + chunk(b'IEND', b'')
sys.stdout.buffer.write(png)
" > "$ICONSET/icon_${s}x${s}.png"
    if [ "$s" -ne 16 ]; then
        cp "$ICONSET/icon_${s}x${s}.png" "$ICONSET/icon_$((s/2))x$((s/2))@2x.png"
    fi
done

echo "   Converting to icns..."
iconutil -c icns "$ICONSET" -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cp "$APP_BUNDLE/Contents/Resources/AppIcon.icns" "$PROJECT_DIR/build/AppIcon.icns"

# Step 4: Create Info.plist
echo ""
echo "==> [4/5] Creating Info.plist..."
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.coremind.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 CoreMind. All rights reserved.</string>
</dict>
</plist>
EOF

# Code sign
echo "   Code signing (ad-hoc)..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "   Verifying..."
codesign -dvvv "$APP_BUNDLE" 2>&1 | grep -E "Identifier|Format|adhoc" || true

# Step 5: Create DMG
echo ""
echo "==> [5/5] Creating DMG..."

# Clean staging
rm -rf "$STAGING"
mkdir -p "$STAGING"

# Copy app into staging
cp -R "$APP_BUNDLE" "$STAGING/"

# Create Applications symlink
ln -s /Applications "$STAGING/Applications"

# Remove old DMG if exists
rm -f "$DMG_PATH"

# Create DMG
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    -imagekey zlib-level=9 \
    "$DMG_PATH"

# Clean up staging
rm -rf "$STAGING"

echo ""
echo "=========================================="
echo " ✅ Done!"
echo "    .app: $APP_BUNDLE ($(du -sh "$APP_BUNDLE" | cut -f1))"
echo "    .dmg: $DMG_PATH ($(du -sh "$DMG_PATH" | cut -f1))"
echo "=========================================="
echo ""
echo "    open \"$DMG_PATH\""
