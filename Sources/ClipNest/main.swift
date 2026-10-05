// Responsibility: accessory app lifecycle, status item, settings, isolated QA mode.
// Development status: complete.
import AppKit
import ClipNestCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    var status: NSStatusItem!
    let loginLaunch = LoginLaunch()
    var guide: MenuBarGuide?
    let popover = NSPopover()
    var store: ClipboardStore!
    var monitor: ClipboardMonitor!
    var panel: PanelView!
    let testing = Bundle.main.bundleIdentifier?.contains(".qa") == true || CommandLine.arguments.contains("--qa-window") || CommandLine.arguments.contains("--ui-test") || CommandLine.arguments.contains("--preview") || CommandLine.arguments.contains("--review-previews") || CommandLine.arguments.contains("--appearance-previews")
    var qaWindow: NSWindow?
    var sampleIndex = 0
    var updateAvailable = false
    let updates = UpdateController()
    func applicationDidFinishLaunching(_ notification: Notification) {
        // LaunchServices normally reopens the first instance. Also guard direct executable launches.
        if let id = Bundle.main.bundleIdentifier,
           let existing = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == id && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            existing.activate(options: []); NSApp.terminate(nil); return
        }
        loginLaunch.disabledForQA = testing
        NSApp.setActivationPolicy(CommandLine.arguments.contains("--qa-window") ? .regular : .accessory)
        let file: URL
        let board: NSPasteboard
        if testing {
            let root = ProcessInfo.processInfo.environment["CLIPNEST_QA_DIR"] ?? NSTemporaryDirectory() + "clipnest-ui-qa"
            file = URL(fileURLWithPath: root).appendingPathComponent("pins.json")
            board = NSPasteboard(name: .init("app.clipnest.qa"))
        } else {
            file = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ClipNest/pins.json")
            board = .general
        }
        store = ClipboardStore(file: file); monitor = ClipboardMonitor(store: store, board: board)
        panel = PanelView(store: store)
        panel.onCopy = { [weak self] text in self?.monitor.copy(text) ?? false }
        panel.onClose = { [weak self] in self?.popover.performClose(nil); self?.qaWindow?.orderOut(nil) }
        panel.onResize = { [weak self] size in self?.popover.contentSize = size }
        panel.onSettings = { [weak self] button in self?.showSettings(button) }
        monitor.onChange = { [weak self] in self?.panel.refresh() }
        let controller = NSViewController(); controller.view = panel
        popover.contentViewController = controller; popover.contentSize = panel.frame.size; popover.behavior = .transient
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = MenuBarIcon.make()
        status.button?.image?.isTemplate = true; status.button?.toolTip = L("ClipNest — pinned snippets + last 3 copies")
        status.button?.target = self; status.button?.action = #selector(toggle)
        status.button?.setAccessibilityLabel(L("ClipNest clipboard"))
        monitor.start()
        updates.onAvailability = { [weak self] available in self?.updateAvailable = available }
        panel.onUpdate = { [weak self] in self?.updates.showUpdate() }
        if !testing {
            updates.start()
            let event = NSAppleEventManager.shared().currentAppleEvent
            let atLogin = event?.paramDescriptor(forKeyword: AEKeyword(keyAELaunchedAsLogInItem)) != nil
            let asService = event?.paramDescriptor(forKeyword: AEKeyword(keyAELaunchedAsServiceItem)) != nil
            if !atLogin && !asService { showGuide() }
        }
        if testing {
            if CommandLine.arguments.contains("--qa-window") {
                for index in 1...12 {
                    store.ingest("Synthetic pin \(index) — a small, clear clipboard helper")
                    _ = store.pin(store.recent[0].id)
                }
                for index in 1...3 { store.ingest("Synthetic recent \(index) — click to pin") }
                panel.refresh()
                let window = NSWindow(contentRect: panel.frame, styleMask: [.titled, .closable], backing: .buffered, defer: false)
                window.title = "ClipNest Synthetic QA"; window.contentView = panel; qaWindow = window
                panel.onResize = { [weak window] size in window?.setContentSize(size) }
                window.center(); window.makeKeyAndOrderFront(nil); window.makeFirstResponder(panel)
                NSApp.activate(ignoringOtherApps: true); return
            }
            if CommandLine.arguments.contains("--review-previews") || CommandLine.arguments.contains("--appearance-previews") {
                renderReviewPreviews()
                return
            }
            if CommandLine.arguments.contains("--preview") {
                for _ in 0..<5 { testCopy(); _ = store.pin(store.recent[0].id) }
                testCopy()
            }
            toggle()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.testScreenshot()
                if CommandLine.arguments.contains("--preview") { NSApp.terminate(nil) }
            }
        }
    }
    func renderReviewPreviews() {
        // Sample text is invented and kept on the dedicated QA pasteboard.
        let samples = [
            "Thanks for the update — I'll take a look today.",
            "Project notes: keep it small, clear, and useful.",
            "https://example.com/team-guide",
            "Meeting agenda: progress, decisions, next steps.",
            "A longer pinned snippet stays complete when copied, even though its single-line preview is shortened to fit this compact menu bar panel.",
            "The draft is ready for a quick review.",
            "Design feedback: a little more breathing room.",
            "Next step: confirm the interface together."
        ]
        for (index, text) in samples.enumerated() {
            monitor.board.clearContents(); monitor.board.setString(text, forType: .string); monitor.poll()
            if index < 7 { _ = store.pin(store.recent[0].id) }
        }
        if CommandLine.arguments.contains("--appearance-previews") {
            panel.appearance = NSAppearance(named: .aqua)
        }
        toggle()
        let root = URL(fileURLWithPath: ProcessInfo.processInfo.environment["CLIPNEST_QA_DIR"] ?? NSTemporaryDirectory() + "clipnest-review")
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if CommandLine.arguments.contains("--appearance-previews") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [self] in
                panel.capture(to: root.appendingPathComponent("ClipNest-Light.png"))
                panel.appearance = NSAppearance(named: .darkAqua)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [self] in
                    panel.capture(to: root.appendingPathComponent("ClipNest-Dark.png"))
                    panel.showUpdateAvailable(true)
                    panel.capture(to: root.appendingPathComponent("ClipNest-Dark-Update.png"))
                    panel.showUpdateAvailable(false)
                    panel.previewDrag()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [self] in
                        panel.capture(to: root.appendingPathComponent("ClipNest-Dark-Trash.png"))
                        NSApp.terminate(nil)
                    }
                }
            }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [self] in
            panel.capture(to: root.appendingPathComponent("ClipNest-01-list.png"))
            panel.previewDrag()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [self] in
                panel.capture(to: root.appendingPathComponent("ClipNest-02-drag-trash.png"))
                let empty = PanelView(store: ClipboardStore(file: root.appendingPathComponent("empty/pins.json")))
                popover.contentViewController?.view = empty
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    empty.capture(to: root.appendingPathComponent("ClipNest-03-empty.png"))
                    NSApp.terminate(nil)
                }
            }
        }
    }
    @objc func toggle() {
        guard let button = status.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else {
            panel.refresh(); popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true); popover.contentViewController?.view.window?.makeFirstResponder(panel)
        }
    }
    func showSettings(_ sender: NSButton) {
        let menu = NSMenu()
        menu.addItem(withTitle: monitor.paused ? L("Resume Clipboard Capture") : L("Pause Clipboard Capture"), action: #selector(pause), keyEquivalent: "")
        let undo = menu.addItem(withTitle: L("Undo Delete"), action: #selector(undo), keyEquivalent: "z"); undo.isEnabled = store.canUndo
        menu.addItem(.separator())
        if updateAvailable { menu.addItem(withTitle: L("Update Available…"), action: #selector(showAvailableUpdate), keyEquivalent: "") }
        let check = menu.addItem(withTitle: updates.configured ? L("Check for Updates…") : L("Updates Not Configured"), action: #selector(checkUpdates), keyEquivalent: "")
        check.isEnabled = !testing && updates.canCheck
        if updates.configured {
            let automatic = menu.addItem(withTitle: L("Check Daily for Updates"), action: #selector(toggleUpdateChecks), keyEquivalent: "")
            automatic.state = updates.automaticChecks ? .on : .off
        }
        menu.addItem(withTitle: L("Menu Bar & Startup…"), action: #selector(showGuide), keyEquivalent: "")
        let loginItem = menu.addItem(withTitle: L("Launch at Login"), action: #selector(toggleLoginLaunch), keyEquivalent: "")
        loginItem.state = loginLaunch.status == .enabled ? .on : loginLaunch.status == .requiresApproval ? .mixed : .off
        loginItem.isEnabled = !testing
        let languageItem = menu.addItem(withTitle: L("Language"), action: nil, keyEquivalent: "")
        let languageMenu = NSMenu()
        let system = languageMenu.addItem(withTitle: L("Follow System"), action: #selector(changeLanguage(_:)), keyEquivalent: "")
        system.tag = -1; system.target = self; system.state = AppLanguage.override == nil ? .on : .off
        for (index, code) in AppLanguage.supported.enumerated() {
            let item = languageMenu.addItem(withTitle: AppLanguage.names[index], action: #selector(changeLanguage(_:)), keyEquivalent: "")
            item.tag = index; item.target = self; item.state = AppLanguage.override == code ? .on : .off
        }
        languageItem.submenu = languageMenu
        menu.addItem(withTitle: L("About & Privacy"), action: #selector(about), keyEquivalent: "")
        if testing {
            menu.addItem(withTitle: "QA: Copy Next Synthetic Sample", action: #selector(testCopy), keyEquivalent: "")
            menu.addItem(withTitle: "QA: Save Synthetic Screenshot", action: #selector(testScreenshot), keyEquivalent: "")
        }
        menu.addItem(.separator()); menu.addItem(withTitle: L("Quit ClipNest"), action: #selector(quit), keyEquivalent: "q")
        menu.autoenablesItems = false
        for item in menu.items { item.target = self }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.minY), in: sender)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let qaWindow { panel.refresh(); qaWindow.makeKeyAndOrderFront(nil); qaWindow.makeFirstResponder(panel) }
        else { showGuide() }
        return false
    }
    @objc func showGuide() {
        if status == nil || !status.isVisible {
            status?.isVisible = true // Restore our own status item; never change system preferences.
        }
        if guide == nil { guide = MenuBarGuide(login: loginLaunch); guide?.onQuit = { NSApp.terminate(nil) } }
        guide?.present()
    }
    @objc func toggleLoginLaunch() { loginLaunch.toggle(); guide?.reload(); if loginLaunch.status == .requiresApproval { showGuide() } }
    @objc func showAvailableUpdate() { updates.showUpdate() }
    @objc func changeLanguage(_ item: NSMenuItem) {
        AppLanguage.select(item.tag < 0 ? nil : AppLanguage.supported[item.tag])
        // Rebuild the complete panel, including accessibility and empty state labels.
        let wasShown = popover.isShown
        popover.performClose(nil)
        let replacement = PanelView(store: store)
        replacement.onCopy = panel.onCopy; replacement.onClose = panel.onClose
        replacement.onSettings = panel.onSettings; replacement.onResize = panel.onResize
        panel = replacement; popover.contentViewController?.view = panel; popover.contentSize = panel.frame.size
        guide?.reload()
        status.button?.toolTip = L("ClipNest — pinned snippets + last 3 copies")
        status.button?.setAccessibilityLabel(L("ClipNest clipboard"))
        if let qaWindow {
            qaWindow.contentView = panel; qaWindow.setContentSize(panel.frame.size)
            panel.onResize = { [weak qaWindow] size in qaWindow?.setContentSize(size) }
            qaWindow.makeKeyAndOrderFront(nil); qaWindow.makeFirstResponder(panel)
        } else if wasShown { toggle() }
    }
    @objc func checkUpdates() { updates.check() }
    @objc func toggleUpdateChecks() { updates.toggleAutomaticChecks() }
    @objc func pause() { monitor.paused.toggle() }
    @objc func undo() { store.undoDelete(); panel.refresh() }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func about() {
        let alert = NSAlert(); alert.messageText = "ClipNest"
        alert.informativeText = L("About privacy") + (store.error == nil ? "" : "\n\n" + L("Storage load error"))
        alert.runModal()
    }
    @objc func testCopy() {
        sampleIndex += 1
        monitor.board.clearContents()
        monitor.board.setString("Synthetic sample \(sampleIndex) — text only, private QA pasteboard. A long preview continues here to verify truncation without exposing personal clipboard content.", forType: .string)
        monitor.poll()
    }
    @objc func testScreenshot() {
        let root = ProcessInfo.processInfo.environment["CLIPNEST_QA_DIR"] ?? NSTemporaryDirectory() + "clipnest-ui-qa"
        try? FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
        panel.capture(to: URL(fileURLWithPath: root).appendingPathComponent("screenshot.png"))
    }
}

func integrationTest() {
    let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("pins.json")
    let store = ClipboardStore(file: file)
    let board = NSPasteboard.withUniqueName(); defer { board.releaseGlobally() }
    let monitor = ClipboardMonitor(store: store, board: board)
    func external(_ text: String, marker: String? = nil) {
        board.clearContents(); board.setString(text, forType: .string)
        if let marker { board.setData(Data(), forType: .init(marker)) }
        monitor.poll()
    }
    for i in 1...5 { external("Synthetic \(i)"); precondition(store.pin(store.recent[0].id)) }
    precondition(store.recent.map(\.text) == ["Synthetic 5", "Synthetic 4", "Synthetic 3"])
    precondition(store.pinned.count == 5)
    monitor.copy("Synthetic 1"); monitor.poll(); precondition(store.recent[0].text == "Synthetic 5")
    precondition(board.string(forType: .string) == "Synthetic 1")
    for marker in ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType", "org.nspasteboard.AutoGeneratedType", "com.agilebits.onepassword"] {
        external("Synthetic excluded", marker: marker); precondition(store.recent[0].text == "Synthetic 5")
    }
    monitor.paused = true; external("Synthetic paused"); monitor.paused = false
    monitor.poll(); precondition(store.recent[0].text == "Synthetic 5")
    let deleted = store.pinned[0].id; precondition(store.delete(deleted))
    let restarted = ClipboardStore(file: file)
    precondition(restarted.pinned.count == 4 && restarted.recent.isEmpty)
    store.undoDelete(); precondition(ClipboardStore(file: file).pinned.count == 5)
    print("PASS: isolated AppKit pasteboard capture/copy, own-write suppression, privacy markers, pause, recent 3, pins >3, delete/undo and restart persistence")
}
if CommandLine.arguments.contains("--interaction-qa") { interactionQA() }
else if CommandLine.arguments.contains("--localization-qa") { localizationQA() }
else if CommandLine.arguments.contains("--update-qa") { updateQATest() }
else if CommandLine.arguments.contains("--integration-test") { integrationTest() }
else {
    let app = NSApplication.shared
    let delegate = AppDelegate(); app.delegate = delegate
    app.run()
}
