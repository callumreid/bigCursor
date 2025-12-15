#!/bin/bash
set -e

APP_NAME="Big Arrow"
BUNDLE_ID="com.bigarrow.app"
VERSION="1.0.0"

echo "🏹 Building Big Arrow..."

swift build -c release

echo "📦 Creating app bundle..."

rm -rf "$APP_NAME.app"
mkdir -p "$APP_NAME.app/Contents/MacOS"
mkdir -p "$APP_NAME.app/Contents/Resources"

cp .build/release/BigArrow "$APP_NAME.app/Contents/MacOS/"

cat > "$APP_NAME.app/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>BigArrow</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
</dict>
</plist>
EOF

echo "🎨 Creating app icon..."

ICON_DIR="$APP_NAME.app/Contents/Resources/AppIcon.iconset"
mkdir -p "$ICON_DIR"

for size in 16 32 128 256 512; do
    double=$((size * 2))
    
    cat > /tmp/arrow_icon.svg << SVGEOF
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#667eea"/>
      <stop offset="100%" style="stop-color:#764ba2"/>
    </linearGradient>
  </defs>
  <rect width="100" height="100" rx="20" fill="url(#bg)"/>
  <g transform="translate(25, 15) scale(3.5)">
    <path d="M2 2 L2 19 L6 15 L11 24 L14 22 L9 13 L14 13 Z" 
          fill="white" stroke="rgba(0,0,0,0.3)" stroke-width="0.5"/>
  </g>
</svg>
SVGEOF
    
    if command -v rsvg-convert &> /dev/null; then
        rsvg-convert -w $size -h $size /tmp/arrow_icon.svg > "$ICON_DIR/icon_${size}x${size}.png"
        rsvg-convert -w $double -h $double /tmp/arrow_icon.svg > "$ICON_DIR/icon_${size}x${size}@2x.png"
    elif command -v sips &> /dev/null; then
        sips -s format png /tmp/arrow_icon.svg --resampleWidth $size --out "$ICON_DIR/icon_${size}x${size}.png" 2>/dev/null || true
    fi
done

if [ -d "$ICON_DIR" ] && [ "$(ls -A $ICON_DIR 2>/dev/null)" ]; then
    iconutil -c icns "$ICON_DIR" -o "$APP_NAME.app/Contents/Resources/AppIcon.icns" 2>/dev/null || true
fi
rm -rf "$ICON_DIR"

echo "📀 Creating DMG..."

rm -f "BigArrow.dmg"
hdiutil create -volname "Big Arrow" -srcfolder "$APP_NAME.app" -ov -format UDZO "BigArrow.dmg" 2>/dev/null || {
    echo "⚠️  DMG creation failed (that's okay, .app still works)"
}

echo ""
echo "✅ Done! Created:"
echo "   📁 $APP_NAME.app - Double-click to run"
if [ -f "BigArrow.dmg" ]; then
    echo "   💿 BigArrow.dmg - Share this file with others"
fi
echo ""
echo "📝 First-time users need to:"
echo "   1. Right-click the app → Open (to bypass Gatekeeper)"
echo "   2. Grant Accessibility permissions when prompted"

