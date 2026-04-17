#!/bin/bash
set -eo pipefail

BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/moonleaf.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RSC_DIR="$CONTENTS_DIR/Resources"
SAVER_BUILD_DIR="${BUILD_DIR}/saver"
SAVER_DIR="${SAVER_BUILD_DIR}/moonleafSaver.saver"

MP_VER_STRING="v3.0.0"
MP_VER_SHORT_STRING="v3.0"

rm -rf ./build

mkdir -p "$MACOS_DIR"
mkdir -p "$RSC_DIR"

echo "building moonleaf ${MP_VER_STRING} to ${BUILD_DIR}"

swiftc \
    -target x86_64-apple-macos12.0 \
    -framework SwiftUI -framework AppKit -framework AVKit \
    -framework AVFoundation -framework UniformTypeIdentifiers \
    -framework Combine -O \
    app/main/*.swift \
    -o "$MACOS_DIR/macpaper_amd64"

echo "compiled moonleaf (amd64)"

swiftc \
    -target arm64-apple-macos12.0 \
    -framework SwiftUI -framework AppKit -framework AVKit \
    -framework AVFoundation -framework UniformTypeIdentifiers \
    -framework Combine -O \
    app/main/*.swift \
    -o "$MACOS_DIR/macpaper_arm64"

echo "compiled moonleaf (arm64)"

lipo -create \
    "$MACOS_DIR/macpaper_amd64" \
    "$MACOS_DIR/macpaper_arm64" \
    -o "$MACOS_DIR/moonleaf"

echo "compiled moonleaf (universal)"
rm "$MACOS_DIR/macpaper_amd64" "$MACOS_DIR/macpaper_arm64"
echo ""

echo "compiling glasswp..."

swiftc \
    -target x86_64-apple-macos12.0 \
    -framework AppKit -framework AVFoundation \
    -framework MediaToolbox -framework Accelerate \
    -O \
    glasswp/glasswp.swift \
    -o "$MACOS_DIR/glasswp_amd64"

echo "compiled glasswp (amd64)"

swiftc \
    -target arm64-apple-macos12.0 \
    -framework AppKit -framework AVFoundation \
    -framework MediaToolbox -framework Accelerate \
    -O \
    glasswp/glasswp.swift \
    -o "$MACOS_DIR/glasswp_arm64"

echo "compiled glasswp (arm64)"

lipo -create "$MACOS_DIR/glasswp_amd64" "$MACOS_DIR/glasswp_arm64" \
    -o "$MACOS_DIR/macpaper Wallpaper Service (glasswp)"

echo "compiled glasswp (universal)"
rm "$MACOS_DIR/glasswp_amd64" "$MACOS_DIR/glasswp_arm64"
echo ""

echo "compiling macpaper-bin..."

gcc -target x86_64-apple-macos12.0 \
    app/obj/macpaper.c -o "$MACOS_DIR/macpaper-bin_amd64"

gcc -target arm64-apple-macos12.0 \
    app/obj/macpaper.c -o "$MACOS_DIR/macpaper-bin_arm64"

lipo -create "$MACOS_DIR/macpaper-bin_amd64" "$MACOS_DIR/macpaper-bin_arm64" \
    -o "$MACOS_DIR/macpaper-bin"

echo "compiled macpaper-bin (universal)"
rm "$MACOS_DIR/macpaper-bin_amd64" "$MACOS_DIR/macpaper-bin_arm64"
echo ""

echo "adding moonleaf Info.plist"
cat > "$CONTENTS_DIR/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>moonleaf</string>
    <key>CFBundleIdentifier</key>
    <string>com.naomisphere.macpaper</string>
    <key>CFBundleName</key>
    <string>moonleaf</string>
    <key>CFBundleDisplayName</key>
    <string>moonleaf</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${MP_VER_SHORT_STRING}</string>
    <key>CFBundleVersion</key>
    <string>${MP_VER_STRING}</string>
    <key>CFBundleIconFile</key>
    <string>moonleaf.icns</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>NSRequiresAquaSystemAppearance</key>
    <false/>
    <key>ATSApplicationFontsPath</key>
    <string>.</string>
</dict>
</plist>
EOF

echo "adding app resources"
cp artwork/icns/moonleaf/moonleaf.icns "$RSC_DIR" 2>/dev/null || true
# cp artwork/png/tear.png "${RSC_DIR}/.macpaper_tear.png" 2>/dev/null || true
cp artwork/png/moonleaf.png "${RSC_DIR}/.moonleaf_logo.png" 2>/dev/null || true
cp artwork/png/moonleaf.png "${RSC_DIR}/StatusBarIcon.png" 2>/dev/null || true
# cp app/updater.sh "${RSC_DIR}/.updater.sh" (embedded in binary)
cp img/png/kofi_symbol.png "$RSC_DIR/.kofi.png" 2>/dev/null || true
cp -R app/resources/* "$RSC_DIR/" 2>/dev/null || true

echo "adding localization strings"
cp -r lang/*.lproj "$RSC_DIR"

echo ""
# echo "building screensaver bundle..."
# mkdir -p "${SAVER_DIR}/Contents/MacOS"
# mkdir -p "${SAVER_DIR}/Contents/Resources"
# 
# cat > "${SAVER_DIR}/Contents/Info.plist" << 'EOF'
# <?xml version="1.0" encoding="UTF-8"?>
# <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
# <plist version="1.0">
# <dict>
#     <key>CFBundleDevelopmentRegion</key>
#     <string>en</string>
#     <key>CFBundleExecutable</key>
#     <string>macpaperSaver</string>
#     <key>CFBundleIdentifier</key>
#     <string>com.naomisphere.macpaper.saver</string>
#     <key>CFBundleInfoDictionaryVersion</key>
#     <string>6.0</string>
#     <key>CFBundleName</key>
#     <string>moonleaf Screensaver</string>
#     <key>CFBundlePackageType</key>
#     <string>BNDL</string>
#     <key>CFBundleShortVersionString</key>
#     <string>1.0</string>
#     <key>CFBundleVersion</key>
#     <string>1</string>
#     <key>NSPrincipalClass</key>
#     <string>macpaperSaverView</string>
# </dict>
# </plist>
# EOF
# 
# swiftc app/main/macpaperSaver.swift \
#     -target x86_64-apple-macos12.0 \
#     -o "${SAVER_DIR}/Contents/MacOS/macpaperSaver_amd64" \
#     -framework ScreenSaver \
#     -framework AVKit \
#     -framework Cocoa \
#     -framework AVFoundation \
#     -Xlinker -bundle
# 
# swiftc app/main/macpaperSaver.swift \
#     -target arm64-apple-macos12.0 \
#     -o "${SAVER_DIR}/Contents/MacOS/macpaperSaver_arm64" \
#     -framework ScreenSaver \
#     -framework AVKit \
#     -framework Cocoa \
#     -framework AVFoundation \
#     -Xlinker -bundle
# 
# lipo -create \
#     "${SAVER_DIR}/Contents/MacOS/macpaperSaver_amd64" \
#     "${SAVER_DIR}/Contents/MacOS/macpaperSaver_arm64" \
#     -o "${SAVER_DIR}/Contents/MacOS/macpaperSaver"
# 
# rm "${SAVER_DIR}/Contents/MacOS/macpaperSaver_amd64" \
#    "${SAVER_DIR}/Contents/MacOS/macpaperSaver_arm64"
# 
# chmod +x "${SAVER_DIR}/Contents/MacOS/macpaperSaver"
# echo "screensaver bundle built at ${SAVER_DIR}"
# 
# cp -r "$SAVER_DIR" "${RSC_DIR}/moonleafSaver.saver"
# echo "screensaver bundled into app Resources"

echo ""
echo "done! moonleaf ${MP_VER_STRING} is at ${BUILD_DIR}/moonleaf.app"
echo ""