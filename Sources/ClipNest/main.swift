// Responsibility: accessory app lifecycle, status item, settings, isolated QA mode.
// Development status: complete.
import AppKit
import ClipNestCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    var status: NSStatusItem!
    let popover = NSPopover()
    var store: ClipboardStore!
    var monitor: ClipboardMonitor!
    var panel: PanelView!
    let testing = CommandLine.arguments.contains("--ui-test") || CommandLine.arguments.contains("--preview") || CommandLine.arguments.contains("--review-previews") || CommandLine.arguments.contains("--appearance-previews")
    var sampleIndex = 0
    let updates = UpdateController()
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
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
        panel.onCopy = { [weak self] text in self?.monitor.copy(text) }
        panel.onClose = { [weak self] in self?.popover.performClose(nil) }
        panel.onSettings = { [weak self] button in self?.showSettings(button) }
        monitor.onChange = { [weak self] in self?.panel.refresh() }
        let controller = NSViewController(); controller.view = panel
        popover.contentViewController = controller; popover.contentSize = panel.frame.size; popover.behavior = .transient
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClipNest")
        status.button?.image?.isTemplate = true; status.button?.toolTip = "ClipNest — pinned snippets + last 3 copies"
        status.button?.target = self; status.button?.action = #selector(toggle)
        status.button?.setAccessibilityLabel("ClipNest clipboard")
        monitor.start()
        updates.onAvailability = { [weak self] available in self?.panel.showUpdateAvailable(available) }
        panel.onUpdate = { [weak self] in self?.updates.showUpdate() }
        if !testing { updates.start() }
        if testing {
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
            if index < 5 { _ = store.pin(store.recent[0].id) }
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
                    panel.showDeletionTarget(true)
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
            panel.showDeletionTarget(true)
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
        menu.addItem(withTitle: monitor.paused ? "Resume Clipboard Capture" : "Pause Clipboard Capture", action: #selector(pause), keyEquivalent: "")
        let undo = menu.addItem(withTitle: "Undo Delete", action: #selector(undo), keyEquivalent: "z"); undo.isEnabled = store.canUndo
        menu.addItem(.separator())
        let check = menu.addItem(withTitle: updates.configured ? "Check for Updates…" : "Updates Not Configured", action: #selector(checkUpdates), keyEquivalent: "")
        check.isEnabled = !testing && updates.canCheck
        if updates.configured {
            let automatic = menu.addItem(withTitle: "Check Daily for Updates", action: #selector(toggleUpdateChecks), keyEquivalent: "")
            automatic.state = updates.automaticChecks ? .on : .off
        }
        menu.addItem(withTitle: "About & Privacy", action: #selector(about), keyEquivalent: "")
        if testing {
            menu.addItem(withTitle: "QA: Copy Next Synthetic Sample", action: #selector(testCopy), keyEquivalent: "")
            menu.addItem(withTitle: "QA: Save Synthetic Screenshot", action: #selector(testScreenshot), keyEquivalent: "")
        }
        menu.addItem(.separator()); menu.addItem(withTitle: "Quit ClipNest", action: #selector(quit), keyEquivalent: "q")
        menu.autoenablesItems = false
        for item in menu.items { item.target = self }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.minY), in: sender)
    }
    @objc func checkUpdates() { updates.check() }
    @objc func toggleUpdateChecks() { updates.toggleAutomaticChecks() }
    @objc func pause() { monitor.paused.toggle() }
    @objc func undo() { store.undoDelete(); panel.refresh() }
    @objc func quit() { NSApp.terminate(nil) }
    @objc func about() {
        let alert = NSAlert(); alert.messageText = "ClipNest"
        alert.informativeText = "Unlimited pinned snippets, only your last 3 distinct text copies.\n\nPins are stored locally as plain text. Recent copies disappear on quit. Update checks contact public GitHub over HTTPS with your permission; no clipboard uploads or system profiling. No analytics. Marked private/password/transient contents are skipped; unmarked sensitive text cannot be identified.\n\nKeyboard: ↑ ↓ or Tab to select, Return to copy/pin, ⌘Delete to delete a pin, ⌘Z to undo, ⌘, for Settings, ⌘Q to quit, Esc to close.\n\nDrag a pin onto the red trash row to delete; release elsewhere to cancel.\n\n" + (store.error ?? "macOS 13+. No auto-start or special permissions.")
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
if CommandLine.arguments.contains("--update-qa") { updateQATest() }
else if CommandLine.arguments.contains("--integration-test") { integrationTest() }
else {
    let app = NSApplication.shared
    let delegate = AppDelegate(); app.delegate = delegate
    app.run()
}
