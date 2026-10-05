#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p /tmp/clipnest-icon-qa-source
preview=$(mktemp -d /tmp/clipnest-icon-qa.XXXXXX)
ditto --norsrc --noextattr /tmp/clipnest-bundle/ClipNest.app "$preview/ClipNest-candidate.app"
swiftc Sources/ClipNest/MenuBarIcon.swift scripts/icon-qa/main.swift -o /tmp/clipnest-icon-qa-source/render
CLIPNEST_ICON_QA_DIR="$preview" /tmp/clipnest-icon-qa-source/render
printf 'Preview directory: %s\n' "$preview"
