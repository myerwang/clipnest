# Validation — 2026-10-05

Apple silicon Mac, Swift 6.4, macOS13 deployment target, Sparkle2.10.0 exact binary dependency.

Passed: release build; six core XCTest cases; isolated AppKit named-pasteboard integration (capture/copy, own-write suppression, privacy markers, pause, latest3, unlimited pins, delete/undo, disk reload); actual AppKit light/dark/trash/update-row rendering inspected using synthetic data; deep strict code-signature validation.

Passed with real Sparkle engine and loopback feeds in disposable QA bundles/defaults: same version (1001), newer version found and dismissed without download, interrupted network (2001), malformed XML (1000), incompatible macOS (1001), valid signed feed/same version (1001), modified signed feed rejected (1000). No installation entered.

Passed with official sign_update and dedicated login Keychain key: valid archive/feed signatures; modified archive/feed rejected. Private key never exported. Public key included in app Info.plist and project config.

Blocked: attempted bad-signature download scenario hits installer-launch error4005 and sandbox_extension_issue_file_to_process before archive signature verification. Installation was not entered; this is not a passing updater-install rejection test. Two-version replacement/relaunch remains unverified.

Not performed: real mouse drag/drop, keyboard/scroll usability, GUI quit/relaunch persistence, manual second-launch permission selection, real user-click update flow. Native accessory-app automation could not identify the app; no whole-desktop capture was used. AppKit layout exports and persistence reload tests do not substitute for those tests.

Distribution: app is ad-hoc signed, not Developer ID signed or notarized; Gatekeeper/translocation may block it. An Ed25519 update signature is independent of Apple's code signing and does not remove that restriction.
