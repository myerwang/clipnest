// Responsibility: Sparkle's verified update engine, consent, and a quiet menu-bar reminder.
// No clipboard data enters this component. No custom downloader or installer.
import AppKit
import Sparkle

final class QuietUpdateDriver: SPUStandardUserDriver {
    var onAvailability: ((Bool) -> Void)?
    private var pending: (SUAppcastItem, SPUUserUpdateState, (SPUUserUpdateChoice) -> Void)?
    override func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Check for ClipNest updates daily?"
        alert.informativeText = "Update checks contact public GitHub over HTTPS. GitHub sees your IP address and ordinary HTTP metadata. Clipboard contents and system profiling are never sent. Updates download only after you click Update. You can change this in Settings."
        alert.addButton(withTitle: "Check Daily"); alert.addButton(withTitle: "Only Manually")
        let allow = alert.runModal() == .alertFirstButtonReturn
        reply(SUUpdatePermissionResponse(automaticUpdateChecks: allow, automaticUpdateDownloading: false, sendSystemProfile: false))
    }
    override func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        // Keep the check in the popover; no progress window to dismiss on a quiet result.
    }
    override func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        // Both manual and scheduled checks stop here. Nothing downloads before a click.
        pending = (appcastItem, state, reply)
        onAvailability?(true)
    }
    func presentPendingUpdate() {
        guard let (item, state, reply) = pending else { return }
        pending = nil
        onAvailability?(false)
        // Keep Sparkle's standard confirmation, progress, signature validation and relaunch UI.
        super.showUpdateFound(with: item, state: state, reply: reply)
    }
    override func dismissUpdateInstallation() {
        pending = nil; onAvailability?(false)
        super.dismissUpdateInstallation()
    }
    override func showUpdateInFocus() {
        if pending != nil { presentPendingUpdate() }
        else { super.showUpdateInFocus() }
    }
}

final class UpdateController: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    private var driver: QuietUpdateDriver!
    private(set) var updater: SPUUpdater?
    var onAvailability: ((Bool) -> Void)?
    var configured: Bool { updater != nil }
    var canCheck: Bool { updater?.canCheckForUpdates ?? false }
    var automaticChecks: Bool { updater?.automaticallyChecksForUpdates ?? false }
    var supportsGentleScheduledUpdateReminders: Bool { true }
    func start() {
        // Never start unconfigured builds or QA: no placeholder key, no unsecured fallback.
        guard let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String,
              Data(base64Encoded: key)?.count == 32 else { return }
        driver = QuietUpdateDriver(hostBundle: .main, delegate: self)
        driver.onAvailability = { [weak self] available in self?.onAvailability?(available) }
        let engine = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: driver, delegate: self)
        do { try engine.start(); updater = engine }
        catch { updater = nil }
    }
    func allowedSystemProfileKeys(for updater: SPUUpdater) -> [String]? { [] }
    func check() { updater?.checkForUpdates() }
    func showUpdate() { driver?.presentPendingUpdate() }
    func toggleAutomaticChecks() {
        guard let updater else { return }
        updater.automaticallyChecksForUpdates.toggle()
    }
}
