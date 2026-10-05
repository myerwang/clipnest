#!/bin/sh
# Faithful resize/format conversion only. No cropping, masking or background removal.
set -eu
cd "$(dirname "$0")/.."
source=docs/icons/ClipNest-app-icon-proposal.png
mkdir -p Resources
iconset=$(mktemp -d /tmp/clipnest-iconset.XXXXXX)/ClipNest.iconset
mkdir "$iconset"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$source" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$source" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o Resources/ClipNest.icns
printf 'Created Resources/ClipNest.icns; unchanged source pixels apart from resizing. Iconset: %s\n' "$iconset"
