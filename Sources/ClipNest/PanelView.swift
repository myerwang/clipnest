// Responsibility: accessible row UI, keyboard navigation, deliberate drag-to-trash. Uses store via delegate.
// Development status: complete.
import AppKit
import ClipNestCore

final class FlippedDocument: NSView {
    override var isFlipped: Bool { true }
}

final class SnippetRow: NSButton {
    override func draw(_ dirtyRect: NSRect) {
        let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 6, yRadius: 6)
        (state == .on ? NSColor.selectedContentBackgroundColor : NSColor.controlBackgroundColor).setFill()
        shape.fill()
        let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: state == .on ? NSColor.alternateSelectedControlTextColor : NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
        (title as NSString).draw(in: NSRect(x: 9, y: 8, width: bounds.width - 18, height: 18), withAttributes: attributes)
    }
    var dragAction: ((SnippetRow, NSEvent) -> Void)?
    var isPinned = false
    override func mouseDown(with event: NSEvent) {
        guard isPinned else { super.mouseDown(with: event); return }
        // Track locally: no clipboard text is placed on a drag pasteboard or exposed to another app.
        let origin = event.locationInWindow
        while let next = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if next.type == .leftMouseUp { performClick(nil); return }
            if hypot(next.locationInWindow.x - origin.x, next.locationInWindow.y - origin.y) >= 5 {
                dragAction?(self, next); return
            }
        }
    }
}

final class PanelView: NSView {
    let store: ClipboardStore
    var onCopy: ((String) -> Void)?
    var onSettings: ((NSButton) -> Void)?
    var onClose: (() -> Void)?
    var onNotice: ((String) -> Void)?
    private let stack = NSStackView()
    private let scroll = NSScrollView()
    private let trash = NSTextField(labelWithString: "Drop here to delete")
    private let footer = NSTextField(labelWithString: "Click a recent copy to pin it")
    private var buttons: [SnippetRow] = []
    private var identities: [(Bool, UUID)] = []
    private var selected = 0
    override var acceptsFirstResponder: Bool { true }
    init(store: ClipboardStore) {
        self.store = store
        super.init(frame: NSRect(x: 0, y: 0, width: 360, height: 500))
        wantsLayer = true; layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        let title = NSTextField(labelWithString: "ClipNest")
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        title.frame = NSRect(x: 18, y: 459, width: 250, height: 24); addSubview(title)
        let settings = NSButton(image: NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")!, target: self, action: #selector(settingsClicked(_:)))
        settings.isBordered = false; settings.frame = NSRect(x: 315, y: 458, width: 28, height: 26)
        settings.setAccessibilityLabel("Settings"); addSubview(settings)
        scroll.frame = NSRect(x: 12, y: 60, width: 336, height: 387)
        scroll.hasVerticalScroller = true; scroll.drawsBackground = false
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        let document = FlippedDocument(); document.addSubview(stack); scroll.documentView = document
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: document.leadingAnchor), stack.trailingAnchor.constraint(equalTo: document.trailingAnchor), stack.topAnchor.constraint(equalTo: document.topAnchor), stack.bottomAnchor.constraint(equalTo: document.bottomAnchor), stack.widthAnchor.constraint(equalToConstant: 314)])
        addSubview(scroll)
        trash.frame = NSRect(x: 16, y: 13, width: 328, height: 36)
        trash.alignment = .center; trash.font = .systemFont(ofSize: 13, weight: .semibold)
        trash.textColor = .white; trash.drawsBackground = true; trash.backgroundColor = .systemRed
        trash.wantsLayer = true; trash.layer?.cornerRadius = 7; trash.isHidden = true; addSubview(trash)
        footer.frame = NSRect(x: 18, y: 18, width: 326, height: 24)
        footer.font = .systemFont(ofSize: 11); footer.textColor = .secondaryLabelColor; addSubview(footer)
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func settingsClicked(_ sender: NSButton) { onSettings?(sender) }
    private func label(_ title: String) {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 11, weight: .semibold); label.textColor = .secondaryLabelColor
        stack.addArrangedSubview(label)
    }
    func refresh() {
        let focusedID = identities.indices.contains(selected) ? identities[selected].1 : nil
        for view in stack.arrangedSubviews { stack.removeArrangedSubview(view); view.removeFromSuperview() }
        buttons = []; identities = []
        label("PINNED SNIPPETS  ·  Click to copy")
        if store.pinned.isEmpty { label("No pins yet. Pin a recent copy below.") }
        for item in store.pinned { row(item, pinned: true) }
        let gap = NSView(); gap.heightAnchor.constraint(equalToConstant: 10).isActive = true; stack.addArrangedSubview(gap)
        label("RECENT 3  ·  Click to pin")
        if store.recent.isEmpty { label("Copy some text to get started.") }
        for item in store.recent { row(item, pinned: false) }
        selected = focusedID.flatMap { id in identities.firstIndex(where: { $0.1 == id }) } ?? min(selected, max(0, buttons.count - 1))
        stack.layoutSubtreeIfNeeded()
        scroll.documentView?.setFrameSize(NSSize(width: 314, height: max(387, stack.fittingSize.height)))
        updateFocus()
        if store.error != nil { footer.stringValue = "Pins file unreadable. See Settings → About." }
    }
    private func row(_ item: Snippet, pinned: Bool) {
        let text = item.text.components(separatedBy: .newlines).joined(separator: "  ")
        let button = SnippetRow(title: String(text.prefix(180)), target: self, action: #selector(rowClicked(_:)))
        button.isPinned = pinned; button.tag = buttons.count
        button.alignment = .left; button.bezelStyle = .recessed; button.isBordered = false
        button.font = .systemFont(ofSize: 13); button.lineBreakMode = .byTruncatingTail
        button.heightAnchor.constraint(equalToConstant: 34).isActive = true
        button.widthAnchor.constraint(equalToConstant: 314).isActive = true
        button.setAccessibilityLabel("\(pinned ? "Copy pinned snippet" : "Pin recent copy"): \(String(text.prefix(180)))")
        button.setAccessibilityHelp(pinned ? "Click to copy. Drag to red trash row to delete. Command Delete deletes selected pin." : "Click to save as a pinned snippet.")
        button.dragAction = { [weak self] row, event in self?.drag(row, first: event) }
        buttons.append(button); identities.append((pinned, item.id)); stack.addArrangedSubview(button)
    }
    @objc private func rowClicked(_ sender: SnippetRow) {
        selected = sender.tag; activateSelection(); window?.makeFirstResponder(self)
    }
    private func activateSelection() {
        guard identities.indices.contains(selected) else { return }
        let (pin, id) = identities[selected]
        if pin, let item = store.pinned.first(where: { $0.id == id }) { onCopy?(item.text); footer.stringValue = "Copied — paste wherever you need it" }
        else {
            if store.pinned.contains(where: { $0.id == id }) || store.recent.first(where: { $0.id == id }).map({ recent in store.pinned.contains(where: { $0.text == recent.text }) }) == true { footer.stringValue = "Already pinned" }
            else if store.pin(id) { footer.stringValue = "Pinned — click it above to copy" }
            else { footer.stringValue = "Could not save pin. Check storage permissions." }
            refresh()
        }
        updateFocus()
    }
    private func drag(_ row: SnippetRow, first: NSEvent) {
        guard identities.indices.contains(row.tag) else { return }
        let id = identities[row.tag].1
        trash.isHidden = false; footer.isHidden = true
        defer { trash.isHidden = true; footer.isHidden = false; trash.backgroundColor = .systemRed }
        var event = first
        while true {
            let point = convert(event.locationInWindow, from: nil)
            let inside = trash.frame.contains(point)
            trash.backgroundColor = inside ? .systemRed.withAlphaComponent(0.75) : .systemRed
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
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "z" { store.undoDelete(); refresh(); return }
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
    func capture(to url: URL) {
        layoutSubtreeIfNeeded()
        guard let rep = bitmapImageRepForCachingDisplay(in: bounds) else { return }
        cacheDisplay(in: bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
