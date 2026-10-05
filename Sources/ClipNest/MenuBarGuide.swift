// Responsibility: configuration-only guidance and explicitly user-controlled macOS login launch.
// Relationship: AppDelegate owns this window; no clipboard data or operations belong here.
// Development status: complete.
import AppKit
import ServiceManagement

final class LoginLaunch {
    var disabledForQA = false
    private let readStatus: () -> SMAppService.Status
    private let register: () throws -> Void
    private let unregister: () throws -> Void
    init(readStatus: @escaping () -> SMAppService.Status = { SMAppService.mainApp.status },
         register: @escaping () throws -> Void = { try SMAppService.mainApp.register() },
         unregister: @escaping () throws -> Void = { try SMAppService.mainApp.unregister() }) {
        self.readStatus = readStatus; self.register = register; self.unregister = unregister
    }
    var status: SMAppService.Status { readStatus() }
    var summary: String {
        switch status {
        case .enabled: return L("Login enabled")
        case .requiresApproval: return L("Login approval needed")
        case .notRegistered: return L("Login disabled")
        case .notFound: return L("Login unavailable")
        @unknown default: return L("Login unavailable")
        }
    }
    // No startup call registers anything. Only a user's Settings action reaches this method.
    func toggle() {
        guard !disabledForQA else { return }
        do {
            if status == .enabled || status == .requiresApproval { try unregister() }
            else { try register() }
        } catch {
            let alert = NSAlert(); alert.messageText = L("Login change failed")
            alert.informativeText = L("Login unavailable"); alert.addButton(withTitle: L("OK")); alert.runModal()
        }
    }
}

final class MenuBarGuide: NSWindowController {
    let login: LoginLaunch
    var onQuit: (() -> Void)?
    private let explanation = NSTextView()
    private let explanationScroll = NSScrollView()
    private let stateLabel = NSTextField(wrappingLabelWithString: "")
    private let loginButton = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let systemButton = NSButton(title: "", target: nil, action: nil)
    private let closeButton = NSButton(title: "", target: nil, action: nil)
    private let quitButton = NSButton(title: "", target: nil, action: nil)
    init(login: LoginLaunch) {
        self.login = login
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 410), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init(window: window); window.isReleasedWhenClosed = false; window.title = "ClipNest"
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 460, height: 410)); window.contentView = root
        explanationScroll.frame = NSRect(x: 24, y: 145, width: 412, height: 238)
        explanationScroll.hasVerticalScroller = true; explanationScroll.autohidesScrollers = true; explanationScroll.drawsBackground = false
        explanation.frame = NSRect(x: 0, y: 0, width: 412, height: 238)
        explanation.isEditable = false; explanation.isSelectable = true; explanation.isRichText = false
        explanation.drawsBackground = false; explanation.font = .systemFont(ofSize: 13); explanation.textColor = .labelColor
        explanation.isVerticallyResizable = true; explanation.isHorizontallyResizable = false
        explanation.textContainer?.widthTracksTextView = true
        explanationScroll.documentView = explanation; root.addSubview(explanationScroll)
        loginButton.frame = NSRect(x: 24, y: 110, width: 412, height: 26)
        loginButton.target = self; loginButton.action = #selector(toggleLogin); root.addSubview(loginButton)
        stateLabel.frame = NSRect(x: 25, y: 62, width: 265, height: 42)
        stateLabel.font = .systemFont(ofSize: 11); stateLabel.textColor = .secondaryLabelColor; root.addSubview(stateLabel)
        systemButton.frame = NSRect(x: 292, y: 71, width: 145, height: 30)
        systemButton.bezelStyle = .rounded; systemButton.target = self; systemButton.action = #selector(openLoginSettings); root.addSubview(systemButton)
        closeButton.frame = NSRect(x: 257, y: 18, width: 180, height: 30)
        closeButton.bezelStyle = .rounded; closeButton.target = self; closeButton.action = #selector(closeGuide); root.addSubview(closeButton)
        quitButton.frame = NSRect(x: 24, y: 18, width: 180, height: 30)
        quitButton.bezelStyle = .rounded; quitButton.target = self; quitButton.action = #selector(quit); root.addSubview(quitButton)
        reload(); window.center()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func reload() {
        explanation.string = L("Menu bar guidance")
        stateLabel.stringValue = login.summary
        loginButton.title = L("Launch at Login"); loginButton.isEnabled = !login.disabledForQA
        loginButton.state = login.status == .enabled ? .on : login.status == .requiresApproval ? .mixed : .off
        systemButton.title = L("Login Settings…"); systemButton.isHidden = login.status != .requiresApproval; systemButton.isEnabled = !login.disabledForQA
        closeButton.title = L("Keep Running"); quitButton.title = L("Quit ClipNest")
    }
    func present() { reload(); showWindow(nil); window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc private func toggleLogin() { login.toggle(); reload() }
    @objc private func openLoginSettings() { guard !login.disabledForQA else { return }; SMAppService.openSystemSettingsLoginItems() }
    @objc private func closeGuide() { window?.orderOut(nil) }
    @objc private func quit() { onQuit?() }
}
