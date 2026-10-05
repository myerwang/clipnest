# Validation — 2026-10-05

Apple silicon Mac, Swift 6.4, macOS13 deployment target, Sparkle2.10.0 exact binary dependency.

Passed: release build; six core XCTest cases; isolated AppKit named-pasteboard integration (capture/copy, own-write suppression, privacy markers, pause, latest3, unlimited pins, delete/undo, disk reload); actual AppKit light/dark/trash/update-row rendering inspected using synthetic data; deep strict code-signature validation.

Passed with real Sparkle engine and loopback feeds in disposable QA bundles/defaults: same version (1001), newer version found and dismissed without download, interrupted network (2001), malformed XML (1000), incompatible macOS (1001), valid signed feed/same version (1001), modified signed feed rejected (1000). No installation entered.

Passed with official sign_update and dedicated login Keychain key: valid archive/feed signatures; modified archive/feed rejected. Private key never exported. Public key included in app Info.plist and project config.

Blocked: attempted bad-signature download scenario hits installer-launch error4005 and sandbox_extension_issue_file_to_process before archive signature verification. Installation was not entered; this is not a passing updater-install rejection test. Two-version replacement/relaunch remains unverified.

Not performed: real mouse drag/drop, keyboard/scroll usability, GUI quit/relaunch persistence, manual second-launch permission selection, real user-click update flow. Native accessory-app automation could not identify the app; no whole-desktop capture was used. AppKit layout exports and persistence reload tests do not substitute for those tests.

Historical 0.1.0/0.1.1 distribution: app is ad-hoc signed, not Developer ID signed or notarized; Gatekeeper/translocation may block it. An Ed25519 update signature is independent of Apple's code signing and does not remove that restriction.

## DMG first-install package

The 0.1.0 DMG was packaged from the already-published ZIP without rebuild/re-signing. hdiutil image checksum passed. A read-only mount verified the full ClipNest.app file/symlink inventory matched the released ZIP, Applications linked to /Applications, installation text was present, and codesign --deep --strict passed. The exact test volume was detached and checked unmounted; no installed app was touched. ZIP/feed remain unchanged. DMG is not notarized and does not bypass Gatekeeper.

## Local 0.1.1 icon candidate

Native build, six XCTest cases and isolated clipboard integration passed again. Complete ten-size ICNS built from approved PNG using only faithful resize/format conversion; application Info.plist embeds the icon. Actual NSWorkspace icon render on this Mac showed normal rounded presentation without a white corner square; earlier macOS rendering has not been verified. Same 18pt isTemplate glyph with two internal lines rendered through NSImageView for aqua/darkAqua, with no annotation circle. This remains offscreen native API validation, not real Finder/menu-bar screenshot or mouse acceptance.

New DMG created from new ZIP; image checksum, read-only mounted app/symlink inventory equality, icon-resource presence, nested codesign and exact own-volume detach passed. Original0.1.0 ZIP unchanged. New ZIP/feed signatures and independent modified-input rejection passed; seven Sparkle-engine feed scenarios passed for build2. Installer replacement/relaunch and blocked bad-signature download case retain the previously stated limitations.

## 0.1.2 Developer ID and Apple notarization

Built an isolated source snapshot with version0.1.2/build3. No product behavior changed. Six components (Installer, Downloader, Autoupdate, Updater, Sparkle framework and main app) signed inside-out with the authorized team C2C48NP2VN, Hardened Runtime and secure timestamps. Downloader's existing empty entitlements preserved; no debug entitlement or relaxed library validation. Private keys remained in login Keychain.

App submission e54ec0e9-6b9d-4886-a396-6cadb4100edf: Accepted, no issues. DMG submission 83ce71ab-d88e-4e3b-af96-372ca3bc22c4: Accepted, no issues. App and DMG stapled-ticket validation and strict code-signature checks passed. Official spctl assessments accepted App (execute) and DMG (open/primary-signature) as Notarized Developer ID. ZIP extraction preserved the App ticket. Read-only DMG mount matched the entire ZIP app inventory and symlinks; exact test volume detached.

The freshly signed app passed the isolated AppKit integration test. macOS LaunchServices/trust checks require the ordinary host execution context and failed inside the agent filesystem sandbox; the same official checks passed outside that sandbox without changing any system security setting. Independent EdDSA verification passed for final ZIP/feed and rejected modified ZIP/feed. No installed app or general clipboard was accessed. The real mouse/keyboard/GUI restart and two-version updater replacement boundaries remain unverified as stated above.
