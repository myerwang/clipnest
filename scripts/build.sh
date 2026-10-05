#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
CLANG_MODULE_CACHE_PATH=/tmp/clipnest-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/clipnest-module-cache swift build -c release --disable-sandbox --cache-path /tmp/clipnest-swift-cache --scratch-path /tmp/clipnest-build --build-system native
mkdir -p /tmp/clipnest-bundle/ClipNest.app/Contents/MacOS
cp /tmp/clipnest-build/release/ClipNest /tmp/clipnest-bundle/ClipNest.app/Contents/MacOS/ClipNest
cat > /tmp/clipnest-bundle/ClipNest.app/Contents/Info.plist <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>ClipNest</string>
<key>CFBundleIdentifier</key><string>app.clipnest.mac</string>
<key>CFBundleName</key><string>ClipNest</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
xattr -cr /tmp/clipnest-bundle/ClipNest.app
codesign --force --sign - /tmp/clipnest-bundle/ClipNest.app
mkdir -p dist
ditto --norsrc --noextattr /tmp/clipnest-bundle/ClipNest.app dist/ClipNest.app
ditto -c -k --keepParent --norsrc --noextattr /tmp/clipnest-bundle/ClipNest.app dist/ClipNest-0.1.0-macos-arm64.zip
printf 'Built %s/dist/ClipNest.app\n' "$PWD"
