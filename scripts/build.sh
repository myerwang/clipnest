#!/bin/sh
set -eu
bundle_root=${CLIPNEST_BUNDLE_ROOT:-/tmp/clipnest-bundle}
dist_root=${CLIPNEST_DIST_ROOT:-dist}
cd "$(dirname "$0")/.."
version=$(python3 -c 'import json; print(json.load(open("config/version.json"))["version"])')
build=$(python3 -c 'import json; print(json.load(open("config/version.json"))["build"])')
./scripts/build-icons.sh
CLANG_MODULE_CACHE_PATH=/tmp/clipnest-module-cache SWIFTPM_MODULECACHE_OVERRIDE=/tmp/clipnest-module-cache swift build -c release --disable-sandbox --cache-path /tmp/clipnest-swift-cache --scratch-path /tmp/clipnest-build --build-system native
mkdir -p "$bundle_root/ClipNest.app/Contents/MacOS"
mkdir -p "$bundle_root/ClipNest.app/Contents/Frameworks"
ditto --norsrc --noextattr /tmp/clipnest-build/release/Sparkle.framework "$bundle_root/ClipNest.app/Contents/Frameworks/Sparkle.framework"
cp /tmp/clipnest-build/release/ClipNest "$bundle_root/ClipNest.app/Contents/MacOS/ClipNest"
cat > "$bundle_root/ClipNest.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>ClipNest</string>
<key>CFBundleIdentifier</key><string>app.clipnest.mac</string>
<key>CFBundleName</key><string>ClipNest</string>
<key>CFBundleDevelopmentRegion</key><string>en</string>
<key>CFBundleLocalizations</key><array><string>en</string><string>zh-Hans</string><string>zh-Hant</string><string>ja</string><string>ko</string><string>es</string><string>fr</string><string>de</string></array>
<key>CFBundleIconFile</key><string>ClipNest</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>VERSION_PLACEHOLDER</string>
<key>CFBundleVersion</key><string>BUILD_PLACEHOLDER</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><true/>
<key>LSMultipleInstancesProhibited</key><true/>
<key>NSHighResolutionCapable</key><true/>
<key>SUFeedURL</key><string>https://raw.githubusercontent.com/myerwang/clipnest/main/appcast.xml</string>
<key>SUScheduledCheckInterval</key><real>86400</real>
<key>SUAutomaticallyUpdate</key><false/>
<key>SUAllowsAutomaticUpdates</key><false/>
<key>SUEnableSystemProfiling</key><false/>
<key>SUShowReleaseNotes</key><false/>
<key>SUVerifyUpdateBeforeExtraction</key><true/>
<key>SURequireSignedFeed</key><true/>
<key>SUSignedFeedFailureExpirationInterval</key><real>0</real>
</dict></plist>
PLIST
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$bundle_root/ClipNest.app/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build" "$bundle_root/ClipNest.app/Contents/Info.plist"
# The public key is safe to publish; no private key ever enters this script.
if [ -f config/sparkle-public-key.txt ]; then
    /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $(cat config/sparkle-public-key.txt)" "$bundle_root/ClipNest.app/Contents/Info.plist"
fi
mkdir -p "$bundle_root/ClipNest.app/Contents/Resources"
cp Resources/ClipNest.icns "$bundle_root/ClipNest.app/Contents/Resources/ClipNest.icns"
for localization in Resources/*.lproj; do ditto "$localization" "$bundle_root/ClipNest.app/Contents/Resources/$(basename "$localization")"; done
xattr -cr "$bundle_root/ClipNest.app"
codesign --force --sign - "$bundle_root/ClipNest.app"
mkdir -p "$dist_root"
ditto --norsrc --noextattr "$bundle_root/ClipNest.app" "$dist_root/ClipNest.app"
ditto -c -k --keepParent --norsrc --noextattr "$bundle_root/ClipNest.app" "$dist_root/ClipNest-$version-macos-$(uname -m).zip"
printf 'Built %s/ClipNest.app\n' "$dist_root"
