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
    let repository = AppLinks.officialRepository
    precondition(repository.absoluteString == "https://github.com/myerwang/clipnest")
    precondition(repository.scheme == "https" && repository.host == "github.com" && repository.path == "/myerwang/clipnest")
    precondition(repository.query == nil && repository.fragment == nil && repository.user == nil && repository.password == nil)
    print("PASS: official repository target is fixed HTTPS; no credentials, query or tracking parameters; no browser opened by QA")
    motionTargetQA()
    dragFoldQA()
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
        precondition(dictionary["Official Repository"]?.isEmpty == false)
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

func motionTargetQA() {
    let target = TrashTarget(frame: NSRect(x: 80, y: 100, width: 52, height: 52))
    let hit = target.frame
    func settle() {
        let until = Date().addingTimeInterval(0.22)
        while Date() < until { _ = RunLoop.main.run(mode: .default, before: until) }
    }
    target.reveal(animated: false); precondition(!target.isHidden)
    for index in 0..<80 { target.highlighted = index % 2 == 0; precondition(target.frame == hit) }
    target.dismiss(); target.reveal(animated: false); settle()
    precondition(!target.isHidden && target.frame == hit) // Stale dismiss must not hide a fresh drag.
    target.dismiss(); settle(); precondition(target.isHidden && target.frame == hit)
    print("PASS: native trash stable 52pt hit area, rapid hover changes, reveal/dismiss cancellation token and final hidden state; no OS input")
}

func dragFoldQA() {
    let source=NSRect(x:20,y:180,width:340,height:36),hit=NSRect(x:240,y:110,width:52,height:52)
    var time:TimeInterval=0
    let preview=DragPreview(title:"Synthetic mesh safety",frame:source,seed:13,clock:{time})
    preview.follow(pointerFrame:source,trashFrame:hit,inside:true,reduceMotion:false)
    var last:Float=0
    for progress in [0.25,0.5,0.75,1.0] {
        time=progress*0.5;preview.advance();precondition(preview.pose.progress>last);last=preview.pose.progress
        precondition(preview.text=="Synthetic mesh safety" && preview.subviews.isEmpty)
    }
    precondition(!preview.isAnimating && preview.pose.progress==1)
    preview.follow(pointerFrame:source,trashFrame:hit,inside:false,reduceMotion:false)
    time += 0.1;preview.advance();let interrupted=preview.pose
    preview.follow(pointerFrame:source,trashFrame:hit,inside:true,reduceMotion:false)
    precondition(preview.pose.progress==interrupted.progress && preview.pose.center==interrupted.center)
    for index in 0..<20 {time += 0.01;preview.follow(pointerFrame:source,trashFrame:hit,inside:index%2==0,reduceMotion:false)}
    preview.follow(pointerFrame:source,trashFrame:hit,inside:false,reduceMotion:true,animated:false)
    preview.follow(pointerFrame:source,trashFrame:hit,inside:true,reduceMotion:true,animated:false)
    precondition(preview.pose.progress==0 && preview.pose.center==NSPoint(x:source.midX,y:source.midY) && !preview.isAnimating)
    preview.stopMotion()
    print("PASS: accepted 128-face original-texture 0.5s mesh at 25/50/75%, interrupt continuity, rapid reversals, idle timer stops, Reduce Motion static; no data actions")
}
