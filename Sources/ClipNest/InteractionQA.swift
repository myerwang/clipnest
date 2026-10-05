// Responsibility: isolated AppKit callback/locale regression harness; never general pasteboard or login registration.
// Development status: complete.
import AppKit
import ClipNestCore
import ServiceManagement

func interactionQA() {
    precondition(Bundle.main.bundleIdentifier?.hasSuffix(".qa") == true)
    _ = NSApplication.shared
    let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = ClipboardStore(file: root.appendingPathComponent("pins.json"))
    store.ingest("Synthetic A"); precondition(store.pin(store.recent[0].id))
    store.ingest("Synthetic B"); precondition(store.pin(store.recent[0].id))
    let panel = PanelView(store: store)
    func key(_ code: UInt16) {
        panel.keyDown(with: NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: false, keyCode: code)!)
    }
    var closes = 0
    panel.onClose = { closes += 1 }
    panel.onCopy = { _ in false }
    key(125); key(36)
    precondition(closes == 0 && store.pinned[0].copyCount == 0)
    let board = NSPasteboard.withUniqueName(); defer { board.releaseGlobally() }
    let monitor = ClipboardMonitor(store: store, board: board)
    panel.onCopy = { monitor.copy($0) }
    key(36)
    precondition(closes == 1 && store.pinned[0].copyCount == 1)
    precondition(board.string(forType: .string) == "Synthetic A")
    precondition(ClipboardStore(file: root.appendingPathComponent("pins.json")).sortedPins.first?.text == "Synthetic A")
    print("PASS: AppKit action callbacks; failed copy remains open/unranked, successful private-board copy closes immediately and persists usage")
    loginLaunchQA()
    localizationQA()
}

func localizationQA() {
    precondition(Bundle.main.bundleIdentifier?.hasSuffix(".qa") == true)
    let old = AppLanguage.override
    defer { AppLanguage.select(old) }
    var expectedKeys: Set<String>?
    for language in AppLanguage.supported {
        AppLanguage.select(language)
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let dictionary = NSDictionary(contentsOfFile: path + "/Localizable.strings") as? [String: String] else { fatalError("Missing locale resources") }
        let keys = Set(dictionary.keys)
        if let expectedKeys { precondition(keys == expectedKeys) } else { expectedKeys = keys }
        precondition(dictionary.values.allSatisfy { !$0.isEmpty })
        precondition(L("Pinned snippets") == dictionary["Pinned snippets"])
        precondition(L("Menu bar guidance") == dictionary["Menu bar guidance"])
        precondition(AppLanguage.bundle.bundlePath.hasSuffix(language + ".lproj"))
    }
    AppLanguage.select(nil)
    print("PASS: all 8 locale catalogs have identical complete keys; immediate app-only override; system/per-app bundle choice=\(Bundle.main.preferredLocalizations.first ?? "en")")
}

func loginLaunchQA() {
    var state: SMAppService.Status = .notRegistered
    var registers = 0, unregisters = 0
    let login = LoginLaunch(readStatus: { state }, register: { registers += 1; state = .enabled }, unregister: { unregisters += 1; state = .notRegistered })
    precondition(registers == 0 && unregisters == 0) // Construction/startup never opts in.
    login.disabledForQA = true; login.toggle(); precondition(registers == 0)
    login.disabledForQA = false; login.toggle(); precondition(state == .enabled && registers == 1)
    login.toggle(); precondition(state == .notRegistered && unregisters == 1)
    state = .requiresApproval; precondition(login.summary == L("Login approval needed"))
    login.toggle(); precondition(state == .notRegistered && unregisters == 2)
    state = .notFound; precondition(login.summary == L("Login unavailable"))
    print("PASS: injected login-service transitions and approval/unavailable guidance; zero real registration or reboot")
}
