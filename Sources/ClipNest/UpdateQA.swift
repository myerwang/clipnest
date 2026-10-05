// Isolated Sparkle-engine regression harness. Never uses the clipboard or production bundle.
import AppKit
import Sparkle

final class UpdateQADriver: SPUStandardUserDriver {
    var expected = ""
    var found = false
    var installationReached = false
    override func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {}
    override func showUpdateFound(with item: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        found = true
        // Only the deliberately invalid-signature fixture may be downloaded.
        reply(expected == "signature" ? .install : .dismiss)
    }
    override func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) { acknowledgement() }
    override func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) { acknowledgement() }
    override func showDownloadInitiated(cancellation: @escaping () -> Void) {}
    override func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {}
    override func showDownloadDidReceiveData(ofLength length: UInt64) {}
    override func showDownloadDidStartExtractingUpdate() {}
    override func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        installationReached = true; reply(.skip)
    }
    override func dismissUpdateInstallation() {}
}
final class UpdateQA: NSObject, SPUUpdaterDelegate {
    let driver = UpdateQADriver(hostBundle: .main, delegate: nil)
    var engine: SPUUpdater!
    let scenario: String
    init(scenario: String) { self.scenario = scenario; super.init(); driver.expected = scenario }
    func start() {
        guard Bundle.main.bundleIdentifier?.hasPrefix("app.clipnest.update-qa.") == true,
              let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String,
              feed.hasPrefix("http://127.0.0.1:") else { fatalError("QA requires a dedicated local test bundle and loopback feed") }
        engine = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: driver, delegate: self)
        do { try engine.start() } catch { print("FAIL: updater start \(error)"); exit(1) }
        DispatchQueue.main.async { self.engine.checkForUpdates() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) { print("FAIL: updater timeout"); exit(1) }
    }
    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        let code = (error as NSError?)?.code
        let passed: Bool
        switch scenario {
        case "newer": passed = driver.found && error == nil
        case "same", "incompatible", "signedsame": passed = !driver.found && code == 1001
        case "offline", "malformed", "signedtampered": passed = !driver.found && error != nil
        case "signature": passed = driver.found && [3001, 3002].contains(code ?? 0) && !driver.installationReached
        default: passed = false
        }
        print("\(passed ? "PASS" : "FAIL"): Sparkle \(scenario); found=\(driver.found); error=\(code.map(String.init) ?? "none"); installationReached=\(driver.installationReached)")
        exit(passed ? 0 : 1)
    }
}
func updateQATest() {
    let app = NSApplication.shared; app.setActivationPolicy(.accessory)
    let test = UpdateQA(scenario: ProcessInfo.processInfo.environment["CLIPNEST_UPDATE_QA_SCENARIO"] ?? "")
    test.start(); withExtendedLifetime(test) { app.run() }
}
