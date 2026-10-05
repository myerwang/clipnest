# ClipNest development guide

## 项目阶段
开发期。New macOS MVP, no production users. Updated 2026-10-05.

## 账号绑定
Authorized GitHub destination: myerwang/clipnest-macos. Account ID 7298618 verified using the GitHub connector. Local gh authorization is invalid; do not use it for writes until reverified. Approved git author/committer: myerwang <7298618+myerwang@users.noreply.github.com>. Use repository-local git config only. Never use the real email or infer author identity from global configuration.
Bundle ID: app.clipnest.mac. Local ad-hoc signing only; no Apple Developer team or distribution account.

## 计费点清单
None. No hosted services or paid APIs.

## 例外清单
None. User explicitly authorized this new public repository and its source/docs only, with local development fallback when formal Codex cloud environment creation is unavailable.

## Scope and commands
English source/UI/README. Chinese user communication. Native AppKit, macOS 13+, no dependencies. Read this file before changes.
- `swift test`: core logic and persistence tests.
- `./scripts/build.sh`: release .app in dist, ad-hoc signed.
- `open dist/ClipNest.app`: normal menu bar app.
- `dist/ClipNest.app/Contents/MacOS/ClipNest --integration-test`: isolated pasteboard and persistence checks; no general clipboard access.
- `dist/ClipNest.app/Contents/MacOS/ClipNest --ui-test`: isolated synthetic GUI QA. Settings menu has a test copy action. Never run normal mode when capturing screenshots containing private clipboard data.

## Architecture
`Sources/ClipNestCore/ClipboardStore.swift`: deduplicated recent three, pinned records, atomic disk writes. Recent data never persisted.
`Sources/ClipNest/ClipboardMonitor.swift`: polls changeCount, filters privacy markers before reading text, ignores own writes and pre-launch clipboard.
`Sources/ClipNest/PanelView.swift`: rows, scroll, drag threshold and red trash target, keyboard controls.
`Sources/ClipNest/main.swift`: LSUIElement status item, popover, settings and test harness.
`Tests/ClipNestCoreTests`: behavior tests. `scripts/build.sh`: bundle packaging. `docs/screenshot.png`: synthetic preview.

## Invariants
Keep exactly three distinct recent texts newest first; own copies do not add history. Only pins persist, locally in Application Support/ClipNest/pins.json (plain text; private file permissions). Never log clipboard contents. Check all pasteboard items for privacy markers before reading. No network, analytics, auto-launch, accessibility or screen-recording requests. Do not add search, sync, or unlimited history. Drag cancellation must preserve data; deletion requires release inside the visible trash row. Preserve Undo Delete and keyboard alternative. Test only synthetic data using private pasteboard and temp storage. Do not commit dist, .build, credentials, user data or machine configuration.

## Delivery and cleanup
User approved ClipNest despite existing same-name clipboard apps; do not claim unique branding. Destination is myerwang/clipnest-macos (account ID 7298618).
All local source/build/QA files are temporary. Publish source/docs/tests to GitHub and the local ad-hoc, unnotarized app archive to GitHub Releases. Verify remote downloads and checksums before cleanup. Never remove the only source copy while GitHub login or author approval is pending. After verified delivery, move only project-owned temporary files to Trash recoverably; do not empty Trash or touch toolchains, other projects or app runtime user data.
