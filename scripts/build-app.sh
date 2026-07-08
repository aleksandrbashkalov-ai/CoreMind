#!/bin/bash
# CoreMind macOS App Builder
# Builds a self-contained .app bundle from SPM project
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="CoreMind"
BUILD_DIR="$PROJECT_DIR/.build"
APP_BUNDLE="$PROJECT_DIR/.build/$APP_NAME.app"
CONFIGURATION="${1:-debug}"

echo "==> Building $APP_NAME ($CONFIGURATION)..."

# Step 1: Build with SwiftPM
if [ "$CONFIGURATION" = "release" ]; then
    swift build -c release --product "$APP_NAME"
    BINARY_PATH="$BUILD_DIR/release/$APP_NAME"
else
    swift build --product "$APP_NAME"
    BINARY_PATH="$BUILD_DIR/debug/$APP_NAME"
fi

echo "==> Binary built at: $BINARY_PATH"

# Step 2: Create .app bundle structure
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Step 3: Copy binary
cp "$BINARY_PATH" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Step 4: Compile asset catalog
ASSETS_SRC="$PROJECT_DIR/Sources/CoreMind/Resources/Assets.xcassets"
ASSETS_DST="$APP_BUNDLE/Contents/Resources/Assets.car"

if [ -d "$ASSETS_SRC" ]; then
    echo "==> Compiling asset catalog..."
    xcrun actool \
        "$ASSETS_SRC" \
        --compile "$APP_BUNDLE/Contents/Resources/" \
        --platform macosx \
        --minimum-deployment-target 14.0 \
        --app-icon AppIcon \
        --output-partial-info-plist "$PROJECT_DIR/.build/asset_plist.plist" 2>&1
    echo "==> Assets compiled"
fi

# Step 5: Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>CoreMind</string>
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
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2026 CoreMind. All rights reserved.</string>
</dict>
</plist>
EOF

# Step 6: Copy all non-asset resources
RESOURCES_SRC="$PROJECT_DIR/Sources/CoreMind/Resources"
if [ -d "$RESOURCES_SRC" ]; then
    # Copy everything except xcassets (already compiled)
    rsync -a --exclude='*.xcassets' "$RESOURCES_SRC/" "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true
fi

# Step 7: Sign the app (adhoc for local testing)
echo "==> Signing..."
codesign --force --sign - "$APP_BUNDLE" 2>/dev/null || true

echo ""
echo "✅ $APP_NAME.app built at: $APP_BUNDLE"
echo "   Size: $(du -sh "$APP_BUNDLE" | cut -f1)"
echo ""
echo "   Run with: open \"$APP_BUNDLE\""
echo "   Or:       $APP_BUNDLE/Contents/MacOS/$APP_NAME"
