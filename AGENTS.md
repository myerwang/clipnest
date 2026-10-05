# ClipNest development guide

## 项目阶段
开发期。New macOS MVP, no production users. Updated 2026-10-05.

## 账号绑定
Authorized GitHub destination: myerwang/clipnest. Account ID 7298618 verified using the GitHub connector. Repository created publicly on 2026-10-05 and renamed from clipnest-macos to clipnest with explicit authorization, repository ID 1405073487, browser owner and connector ID both verified. User explicitly authorized the official GitHub CLI HTTPS device OAuth and secure system-credential storage on 2026-10-05 (repo/read:org/gist minimum scopes; actual writes only to this repository). Use project-scoped GH_CONFIG_DIR, no environment token overrides or SSH keys. Credentials must use keychain; stop on plaintext fallback. Verify login myerwang and ID 7298618 before publishing. Official device OAuth completed; CLI login/account ID and Keychain storage verified. Use an isolated Git global config for gh HTTPS helpers. Approved git author/committer: myerwang <7298618+myerwang@users.noreply.github.com>. Use repository-local git config only. Never use the real email or infer author identity from global configuration.
Bundle ID: app.clipnest.mac. Local ad-hoc signing only; no Apple Developer team or distribution account.

## 计费点清单
None. No hosted services or paid APIs.

## 例外清单
None. User explicitly authorized this new public repository and its source/docs and GitHub Releases installation archives, with local development fallback when formal Codex cloud environment creation is unavailable.

## Scope and commands
English source/UI/README. UI follows system appearance via adaptive colors; never change the user's system theme. Chinese user communication. Native AppKit, macOS 13+, no dependencies. Read this file before changes.
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
`Tests/ClipNestCoreTests`: behavior tests. `scripts/build.sh`: bundle packaging. `docs/screenshot-light.png` and `docs/screenshot-dark.png`: actual synthetic AppKit appearance previews; `docs/design`: concept references.

## Invariants
Keep exactly three distinct recent texts newest first; own copies do not add history. Only pins persist, locally in Application Support/ClipNest/pins.json (plain text; private file permissions). Never log clipboard contents. Check all pasteboard items for privacy markers before reading. No clipboard network traffic or analytics; update checks only through Sparkle with user consent. No auto-launch, accessibility or screen-recording requests. Do not add search, sync, or unlimited history. Drag cancellation must preserve data; deletion requires release inside the visible trash row. Preserve Undo Delete and keyboard alternative. Test only synthetic data using private pasteboard and temp storage. Do not commit dist, .build, credentials, user data or machine configuration.

## Delivery and cleanup
User approved ClipNest despite existing same-name clipboard apps; do not claim unique branding. Destination is myerwang/clipnest (account ID 7298618).
User requested persistent local sources under Dream/ClipNest in iCloud Drive (2026-10-05); temporary build/QA files may be cleaned only after verified delivery. Never place private signing keys there. Publish source/docs/tests to GitHub and the local ad-hoc, unnotarized app archive to GitHub Releases. Verify remote downloads and checksums before cleanup. User authorized implementing the redesign directly without another design-approval gate. Publication still requires valid GitHub CLI authorization and identity verification; cleanup waits for verified remote downloads. Never remove the only source copy while GitHub login or author approval is pending. After verified delivery, move only project-owned temporary build/QA files to Trash recoverably; do not empty Trash or touch toolchains, other projects or app runtime user data.

## Updates
Sparkle 2.10.0 exact dependency (macOS12+, project stays13+). UpdateController.swift holds quiet update discovery until explicit row click, then uses Sparkle standard download/signature/install UI. Info.plist leaves SUEnableAutomaticChecks unset for second-launch consent, daily interval, disables automatic downloading/installation and system profiling. Missing public key disables updater entirely. appcast.xml must contain only correctly EdDSA-signed archives; never publish placeholder signatures or private keys. User directly approved dedicated Ed25519 key creation on 2026-10-05. Key was created with official generate_keys into login Keychain account app.clipnest.mac.updates (no existing key, no export); use dedicated login Keychain account, never iCloud/CI/repo. Apple Developer ID/notarization not configured. Runtime data unchanged; GUI replacement E2E must use isolated app/pins/defaults.

First installation uses the DMG; Sparkle continues using the immutable ZIP/feed. `scripts/build-dmg.sh <release-zip>` packages the existing app without rebuilding/signing. Verify mounted DMG read-only, compare the complete app file/symlink tree with the release ZIP, codesign, detach, and re-download/hash-check before reporting success. Never touch installed apps or security settings.
