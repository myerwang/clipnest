#!/bin/sh
# Package an existing release ZIP; never rebuild, re-sign or alter the updater ZIP/feed.
set -eu
cd "$(dirname "$0")/.."
version=$(python3 -c 'import json; print(json.load(open("config/version.json"))["version"])')
archive=${1:-dist/ClipNest-$version-macos-arm64.zip}
output=${2:-dist/ClipNest-$version-macos-arm64.dmg}
if [ -e "$output" ]; then echo 'DMG already exists; refusing to overwrite.' >&2; exit 1; fi
staging=$(mktemp -d /tmp/clipnest-dmg-stage.XXXXXX)
trap 'rmdir "$staging" 2>/dev/null || true' EXIT
mkdir "$staging/content"
ditto -x -k "$archive" "$staging/content"
test -d "$staging/content/ClipNest.app"
codesign --verify --deep --strict "$staging/content/ClipNest.app"
ln -s /Applications "$staging/content/Applications"
status='Development preview: ad-hoc signed, not Developer ID signed or notarized.'
if xcrun stapler validate "$staging/content/ClipNest.app" >/dev/null 2>&1; then
    status='The app is Developer ID signed and Apple notarized with a stapled ticket.'
fi
cat > "$staging/content/INSTALL.txt" <<INSTALL
ClipNest $version — macOS 13+, Apple silicon

Drag ClipNest.app onto Applications. Eject this disk image, then launch
ClipNest from Applications. Its icon appears only in the menu bar.
Do not run the app directly from this read-only disk image.

$status
The container must be signed, notarized and stapled separately for distribution.
This DMG does not bypass Gatekeeper. No system security settings are changed.
The ZIP release remains the Sparkle update archive.
INSTALL
mkdir -p "$(dirname "$output")"
hdiutil create -srcfolder "$staging/content" -volname ClipNest -fs HFS+ -format UDZO "$output"
hdiutil verify "$output"
# Keep temporary source material recoverable until remote delivery is verified.
printf 'DMG: %s\nTemporary packaging source: %s\n' "$output" "$staging"
