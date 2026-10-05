// Responsibility: accessible section cards, adaptive appearance, keyboard navigation and deliberate drag-to-trash.
// Relationship: AppDelegate supplies ClipboardStore and copy/settings callbacks.
// Development status: complete.
import AppKit
import ClipNestCore

private enum Theme {
    static func adaptive(_ light: UInt32, _ dark: UInt32) -> NSColor {
        NSColor(name: nil) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
        }
    }
    static let background = adaptive(0xF4F6F9, 0x1C2027)
    static let card = adaptive(0xFFFFFF, 0x282D36)
    static let pinHeader = adaptive(0xEAF2FF, 0x25384F)
    static let recentHeader = adaptive(0xEFF1F5, 0x303640)
    static let pinBorder = adaptive(0xCBDCF4, 0x3C5677)
    static let recentBorder = adaptive(0xDDE2EA, 0x434B58)
    static let primary = adaptive(0x202C3D, 0xEFF3FA)
    static let secondary = adaptive(0x66758A, 0xA7B4C7)
    static let accent = adaptive(0x316FC4, 0x9CC8FF)
    static let selection = adaptive(0xEAF2FF, 0x334C6C)
    static let separator = adaptive(0xEDF0F5, 0x39414D)
    static let trash = adaptive(0xC93440, 0xBC3541)
}

final class FlippedDocument: NSView {
    override var isFlipped: Bool { true }
}

final class SnippetRow: NSButton {
    var dragAction: ((SnippetRow, NSEvent) -> Void)?
    var isPinned = false
    override func draw(_ dirtyRect: NSRect) {
        if state == .on {
            Theme.selection.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 3, dy: 3), xRadius: 6, yRadius: 6).fill()
        }
        let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byTruncatingTail
        (title as NSString).draw(in: NSRect(x: 12, y: 10, width: bounds.width - 24, height: 18), withAttributes: [
            .font: NSFont.systemFont(ofSize: 13), .foregroundColor: Theme.primary, .paragraphStyle: paragraph
        ])
        Theme.separator.setFill()
        NSRect(x: 12, y: 0, width: bounds.width - 24, height: 1).fill()
    }
    override func mouseDown(with event: NSEvent) {
        guard isPinned else { super.mouseDown(with: event); return }
        // Drag tracking is local: no snippet is placed on an external drag pasteboard.
        let origin = event.locationInWindow
        while let next = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if next.type == .leftMouseUp { performClick(nil); return }
            if hypot(next.locationInWindow.x - origin.x, next.locationInWindow.y - origin.y) >= 5 {
                dragAction?(self, next); return
            }
        }
    }
}

private final class SectionCard: NSView {
    let pinned: Bool
    let titleLabel: NSTextField
    let detailLabel = NSTextField(labelWithString: "")
    let stack = NSStackView()
    let scroll = NSScrollView()
    let emptyLabel = NSTextField(labelWithString: "")
    init(frame: NSRect, pinned: Bool) {
        self.pinned = pinned
        titleLabel = NSTextField(labelWithString: pinned ? "Pinned snippets" : "Recent copies")
        super.init(frame: frame)
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = pinned ? Theme.accent : Theme.primary
        titleLabel.frame = NSRect(x: 36, y: frame.height - 29, width: 180, height: 18); addSubview(titleLabel)
        let symbol = NSImageView(frame: NSRect(x: 14, y: frame.height - 28, width: 15, height: 15))
        symbol.image = NSImage(systemSymbolName: pinned ? "pin.fill" : "clock", accessibilityDescription: nil)
        symbol.contentTintColor = pinned ? Theme.accent : Theme.secondary; addSubview(symbol)
        detailLabel.font = .systemFont(ofSize: 10, weight: .medium)
        detailLabel.textColor = Theme.secondary; detailLabel.alignment = .right
        detailLabel.frame = NSRect(x: frame.width - 117, y: frame.height - 29, width: 100, height: 17); addSubview(detailLabel)
        scroll.frame = NSRect(x: 8, y: 8, width: frame.width - 16, height: frame.height - 50)
        scroll.hasVerticalScroller = pinned; scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        let document = FlippedDocument(); document.addSubview(stack); scroll.documentView = document
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor),
            stack.topAnchor.constraint(equalTo: document.topAnchor),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor),
            stack.widthAnchor.constraint(equalToConstant: frame.width - 32)
        ])
        addSubview(scroll)
        emptyLabel.font = .systemFont(ofSize: 12); emptyLabel.textColor = Theme.secondary
        emptyLabel.maximumNumberOfLines = 2; emptyLabel.alignment = .center
        emptyLabel.frame = NSRect(x: 20, y: (frame.height - 40) / 2 - 15, width: frame.width - 40, height: 40)
        addSubview(emptyLabel)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let shape = NSBezierPath(roundedRect: rect, xRadius: 11, yRadius: 11)
        Theme.card.setFill(); shape.fill()
        NSGraphicsContext.saveGraphicsState(); shape.addClip()
        (pinned ? Theme.pinHeader : Theme.recentHeader).setFill()
        NSRect(x: 0, y: bounds.height - 40, width: bounds.width, height: 40).fill()
        NSGraphicsContext.restoreGraphicsState()
        (pinned ? Theme.pinBorder : Theme.recentBorder).setStroke(); shape.lineWidth = 1; shape.stroke()
    }
    func clear() {
        for view in stack.arrangedSubviews { stack.removeArrangedSubview(view); view.removeFromSuperview() }
    }
    func finish(count: Int) {
        detailLabel.stringValue = pinned ? "\(count) pinned" : "Last 3"
        emptyLabel.stringValue = pinned ? "No pinned snippets yet.\nClick a recent copy to keep it." : "Copy some text to get started."
        emptyLabel.isHidden = count > 0
        stack.layoutSubtreeIfNeeded()
        scroll.documentView?.setFrameSize(NSSize(width: bounds.width - 32, height: max(scroll.bounds.height, stack.fittingSize.height)))
        scroll.contentView.scroll(to: .zero); scroll.reflectScrolledClipView(scroll.contentView)
    }
}

private final class TrashRow: NSView {
    var highlighted = false { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        Theme.trash.withAlphaComponent(highlighted ? 0.8 : 1).setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 7, yRadius: 7).fill()
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .center
        ("Drop here to delete" as NSString).draw(in: NSRect(x: 8, y: 9, width: bounds.width - 16, height: 18), withAttributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor.white, .paragraphStyle: paragraph
        ])
    }
}

final class PanelView: NSView {
    let store: ClipboardStore
    var onCopy: ((String) -> Void)?
    var onSettings: ((NSButton) -> Void)?
    var onClose: (() -> Void)?
    private let pinnedCard: SectionCard
    private let recentCard: SectionCard
    private let trash = TrashRow()
    private let footer = NSTextField(labelWithString: "Click a pin to copy · Click a recent copy to pin")
    private var buttons: [SnippetRow] = []
    private var identities: [(Bool, UUID)] = []
    private var selected = 0
    private var settingsButton: NSButton?
    override var acceptsFirstResponder: Bool { true }
    init(store: ClipboardStore) {
        self.store = store
        pinnedCard = SectionCard(frame: NSRect(x: 16, y: 242, width: 348, height: 230), pinned: true)
        recentCard = SectionCard(frame: NSRect(x: 16, y: 62, width: 348, height: 162), pinned: false)
        super.init(frame: NSRect(x: 0, y: 0, width: 380, height: 538))
        let appSymbol = NSImageView(frame: NSRect(x: 18, y: 492, width: 20, height: 20))
        appSymbol.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: nil)
        appSymbol.contentTintColor = Theme.accent; addSubview(appSymbol)
        let title = NSTextField(labelWithString: "ClipNest")
        title.font = .systemFont(ofSize: 17, weight: .semibold); title.textColor = Theme.primary
        title.frame = NSRect(x: 46, y: 490, width: 250, height: 24); addSubview(title)
        let settings = NSButton(image: NSImage(systemSymbolName: "ellipsis", accessibilityDescription: "Settings")!, target: self, action: #selector(settingsClicked(_:)))
        settings.isBordered = false; settings.contentTintColor = Theme.secondary
        settings.frame = NSRect(x: 334, y: 489, width: 28, height: 26)
        settings.setAccessibilityLabel("Settings"); settings.setAccessibilityHelp("Open settings. Keyboard shortcut Command Comma.")
        settingsButton = settings; addSubview(settings)
        addSubview(pinnedCard); addSubview(recentCard)
        footer.frame = NSRect(x: 18, y: 18, width: 344, height: 20)
        footer.font = .systemFont(ofSize: 11); footer.textColor = Theme.secondary; addSubview(footer)
        trash.frame = NSRect(x: 16, y: 13, width: 348, height: 36)
        trash.isHidden = true; addSubview(trash)
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func draw(_ dirtyRect: NSRect) { Theme.background.setFill(); bounds.fill() }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
        for child in subviews { child.needsDisplay = true }
        for button in buttons { button.needsDisplay = true }
    }
    @objc private func settingsClicked(_ sender: NSButton) { onSettings?(sender) }
    func refresh() {
        let focusedID = identities.indices.contains(selected) ? identities[selected].1 : nil
        let scrollOrigin = pinnedCard.scroll.contentView.bounds.origin
        pinnedCard.clear(); recentCard.clear(); buttons = []; identities = []
        for item in store.pinned { row(item, pinned: true) }
        for item in store.recent { row(item, pinned: false) }
        selected = focusedID.flatMap { id in identities.firstIndex(where: { $0.1 == id }) } ?? min(selected, max(0, buttons.count - 1))
        pinnedCard.finish(count: store.pinned.count); recentCard.finish(count: store.recent.count)
        let maximumY = max(0, (pinnedCard.scroll.documentView?.bounds.height ?? 0) - pinnedCard.scroll.contentSize.height)
        pinnedCard.scroll.contentView.scroll(to: NSPoint(x: 0, y: min(scrollOrigin.y, maximumY)))
        pinnedCard.scroll.reflectScrolledClipView(pinnedCard.scroll.contentView)
        updateFocus()
        if store.error != nil { footer.stringValue = "Pins file unreadable. See Settings → About." }
    }
    private func row(_ item: Snippet, pinned: Bool) {
        let text = item.text.components(separatedBy: .newlines).joined(separator: "  ")
        let button = SnippetRow(title: String(text.prefix(180)), target: self, action: #selector(rowClicked(_:)))
        button.isPinned = pinned; button.tag = buttons.count
        button.isBordered = false; button.font = .systemFont(ofSize: 13)
        button.heightAnchor.constraint(equalToConstant: 36).isActive = true
        button.widthAnchor.constraint(equalToConstant: 316).isActive = true
        button.setAccessibilityLabel("\(pinned ? "Copy pinned snippet" : "Pin recent copy"): \(String(text.prefix(180)))")
        button.setAccessibilityHelp(pinned ? "Click to copy. Drag to red trash row to delete. Command Delete deletes selected pin." : "Click to save as a pinned snippet.")
        button.dragAction = { [weak self] row, event in self?.drag(row, first: event) }
        buttons.append(button); identities.append((pinned, item.id))
        (pinned ? pinnedCard : recentCard).stack.addArrangedSubview(button)
    }
    @objc private func rowClicked(_ sender: SnippetRow) {
        selected = sender.tag; activateSelection(); window?.makeFirstResponder(self)
    }
    private func activateSelection() {
        guard identities.indices.contains(selected) else { return }
        let (pin, id) = identities[selected]
        if pin, let item = store.pinned.first(where: { $0.id == id }) {
            onCopy?(item.text); footer.stringValue = "Copied — paste wherever you need it"
        } else {
            if store.recent.first(where: { $0.id == id }).map({ recent in store.pinned.contains(where: { $0.text == recent.text }) }) == true { footer.stringValue = "Already pinned" }
            else if store.pin(id) { footer.stringValue = "Pinned — click it above to copy" }
            else { footer.stringValue = "Could not save pin. Check storage permissions." }
            refresh()
        }
        updateFocus()
    }
    private func drag(_ row: SnippetRow, first: NSEvent) {
        guard identities.indices.contains(row.tag) else { return }
        let id = identities[row.tag].1
        showDeletionTarget(true); defer { showDeletionTarget(false) }
        var event = first
        while true {
            let point = convert(event.locationInWindow, from: nil)
            let inside = trash.frame.contains(point); trash.highlighted = inside
            if event.type == .leftMouseUp {
                if inside {
                    if store.delete(id) { footer.stringValue = "Deleted — Settings → Undo Delete"; refresh() }
                    else { footer.stringValue = "Could not save deletion. Pin was kept." }
                } else { footer.stringValue = "Deletion cancelled" }
                return
            }
            if event.type == .keyDown && event.keyCode == 53 { footer.stringValue = "Deletion cancelled"; return }
            guard let next = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp, .keyDown]) else { return }
            event = next
        }
    }
    private func updateFocus() {
        for (index, button) in buttons.enumerated() { button.state = index == selected ? .on : .off; button.needsDisplay = true }
    }
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            if event.charactersIgnoringModifiers == "z" { store.undoDelete(); refresh(); return }
            if event.charactersIgnoringModifiers == ",", let button = settingsButton { onSettings?(button); return }
            if event.charactersIgnoringModifiers == "q" { NSApp.terminate(nil); return }
        }
        switch event.keyCode {
        case 125, 48: selected = buttons.isEmpty ? 0 : (selected + (event.modifierFlags.contains(.shift) ? buttons.count - 1 : 1)) % buttons.count
        case 126: selected = max(0, selected - 1)
        case 36, 49: activateSelection(); return
        case 53: onClose?(); return
        case 51, 117:
            if event.modifierFlags.contains(.command), identities.indices.contains(selected), identities[selected].0 {
                let id = identities[selected].1
                let alert = NSAlert(); alert.messageText = "Delete selected pinned snippet?"
                alert.informativeText = "You can undo this from Settings until the next deletion."
                alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Delete")
                if alert.runModal() == .alertSecondButtonReturn { _ = store.delete(id); refresh() }
            }
            return
        default: super.keyDown(with: event); return
        }
        updateFocus()
        if buttons.indices.contains(selected) { buttons[selected].scrollToVisible(buttons[selected].bounds) }
    }
    // Shared visual state for real drag tracking and isolated review rendering.
    func showDeletionTarget(_ visible: Bool) { trash.isHidden = !visible; footer.isHidden = visible; trash.highlighted = false }
    func capture(to url: URL) {
        layoutSubtreeIfNeeded()
        guard let rep = bitmapImageRepForCachingDisplay(in: bounds) else { return }
        cacheDisplay(in: bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
