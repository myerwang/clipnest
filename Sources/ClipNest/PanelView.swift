// Responsibility: single-line bubbles, stable usage ordering, keyboard access and deliberate local drag deletion.
// Relationship: AppDelegate supplies ClipboardStore and success-aware copy/settings callbacks.
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
    static let background = adaptive(0xF7F8FA, 0x1C2027)
    static let pin = adaptive(0xE8F0FA, 0x2B3B50)
    static let recent = adaptive(0xFFFFFF, 0x2B3039)
    static let primary = adaptive(0x243349, 0xEEF3FA)
    static let secondary = adaptive(0x718097, 0xA4B0C0)
    static let accent = adaptive(0x4379B7, 0xA3C9FF)
    static let selection = adaptive(0x6892C5, 0x88B3EE)
    static let trash = adaptive(0xC64552, 0xBE4553)
}

final class FlippedDocument: NSView { override var isFlipped: Bool { true } }

final class SnippetRow: NSButton {
    var dragAction: ((SnippetRow, NSEvent) -> Void)?
    var isPinned = false
    private(set) var dragOriginInWindow: NSPoint?
    var placeholder = false { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 11, yRadius: 11)
        (isPinned ? Theme.pin : Theme.recent).withAlphaComponent(placeholder ? 0.18 : NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency ? 1 : 0.68).setFill(); shape.fill()
        if state == .on && !placeholder {
            Theme.selection.withAlphaComponent(0.7).setStroke(); shape.lineWidth = 1; shape.stroke()
        }
        guard !placeholder else { return }
        let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byTruncatingTail
        (title as NSString).draw(in: NSRect(x: 13, y: (bounds.height - 18) / 2, width: bounds.width - 26, height: 18), withAttributes: [
            .font: NSFont.systemFont(ofSize: 13), .foregroundColor: Theme.primary, .paragraphStyle: paragraph
        ])
    }
    override func mouseDown(with event: NSEvent) {
        guard isPinned else { super.mouseDown(with: event); return }
        // No external drag pasteboard: contents stay inside this panel.
        let origin = event.locationInWindow; dragOriginInWindow = origin
        while let next = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp, .keyDown]) {
            if next.type == .keyDown && next.keyCode == 53 { return }
            if next.type == .leftMouseUp { if bounds.contains(convert(next.locationInWindow, from: nil)) { performClick(nil) }; return }
            if next.type == .leftMouseDragged && hypot(next.locationInWindow.x - origin.x, next.locationInWindow.y - origin.y) >= 5 {
                dragAction?(self, next); return
            }
        }
    }
}

private final class BubbleSection: NSView {
    let pinned: Bool
    let titleLabel: NSTextField
    let detailLabel = NSTextField(labelWithString: "")
    let document = FlippedDocument()
    let scroll = NSScrollView()
    let emptyLabel = NSTextField(labelWithString: "")
    init(pinned: Bool) {
        self.pinned = pinned
        titleLabel = NSTextField(labelWithString: L(pinned ? "Pinned snippets" : "Recent copies"))
        super.init(frame: .zero)
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = pinned ? Theme.accent : Theme.secondary; addSubview(titleLabel)
        detailLabel.font = .systemFont(ofSize: 11); detailLabel.textColor = Theme.secondary
        detailLabel.alignment = .right; addSubview(detailLabel)
        scroll.hasVerticalScroller = pinned; scroll.autohidesScrollers = true; scroll.scrollerStyle = .overlay
        scroll.drawsBackground = false; scroll.documentView = document; addSubview(scroll)
        emptyLabel.font = .systemFont(ofSize: 12); emptyLabel.textColor = Theme.secondary
        emptyLabel.maximumNumberOfLines = 2; emptyLabel.alignment = .center; addSubview(emptyLabel)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func arrange(_ rows: [SnippetRow], count: Int) {
        titleLabel.frame = NSRect(x: 3, y: bounds.height - 22, width: 215, height: 18)
        detailLabel.frame = NSRect(x: bounds.width - 100, y: bounds.height - 22, width: 97, height: 18)
        detailLabel.stringValue = pinned ? String(count) : L("Last 3")
        scroll.frame = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - 34)
        for child in document.subviews { child.removeFromSuperview() }
        let width = bounds.width - (pinned && rows.count > 9 ? 10 : 0)
        for (index, row) in rows.enumerated() {
            row.frame = NSRect(x: 0, y: CGFloat(index) * 42, width: width, height: 36); document.addSubview(row)
        }
        document.frame = NSRect(x: 0, y: 0, width: bounds.width, height: max(scroll.contentSize.height, CGFloat(rows.count) * 42 - 6))
        emptyLabel.stringValue = L(pinned ? "No pins yet. Click a recent copy to keep it." : "Copy some text to get started.")
        emptyLabel.frame = NSRect(x: 16, y: max(8, (bounds.height - 70) / 2), width: bounds.width - 32, height: 38)
        emptyLabel.isHidden = count > 0
    }
}

private final class TrashRow: NSView {
    var highlighted = false { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        let circle = NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1))
        (highlighted ? Theme.trash : Theme.background).withAlphaComponent(0.96).setFill(); circle.fill()
        Theme.trash.withAlphaComponent(highlighted ? 1 : 0.55).setStroke(); circle.lineWidth = 1.5; circle.stroke()
        let image = NSImage(systemSymbolName: "trash.fill", accessibilityDescription: nil)!
        let config = NSImage.SymbolConfiguration(pointSize: 23, weight: .medium)
            .applying(.init(paletteColors: [highlighted ? .white : Theme.trash]))
        image.withSymbolConfiguration(config)?.draw(in: NSRect(x: 15, y: 14, width: 22, height: 24))
    }
}

final class PanelView: NSView {
    let store: ClipboardStore
    var onCopy: ((String) -> Bool)?
    var onSettings: ((NSButton) -> Void)?
    var onClose: (() -> Void)?
    var onResize: ((NSSize) -> Void)?
    var onUpdate: (() -> Void)? // Kept for isolated updater QA; actual action lives in Settings.
    private let pinnedSection = BubbleSection(pinned: true)
    private let recentSection = BubbleSection(pinned: false)
    private let material = NSVisualEffectView()
    private let trash = TrashRow()
    private let footer = NSTextField(labelWithString: "")
    private let undoButton = NSButton(title: L("Undo"), target: nil, action: nil)
    private let titleLabel = NSTextField(labelWithString: "ClipNest")
    private var settingsButton: NSButton!
    private var buttons: [SnippetRow] = []
    private var identities: [(Bool, UUID)] = []
    private var selected = -1
    private var dragging = false
    private var animating = false
    private var lifted: SnippetRow?
    private var undoTimer: Timer?
    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    override var acceptsFirstResponder: Bool { true }
    init(store: ClipboardStore) {
        self.store = store
        super.init(frame: NSRect(x: 0, y: 0, width: 380, height: 410))
        material.frame = bounds; material.autoresizingMask = [.width, .height]
        material.material = .popover; material.blendingMode = .behindWindow; material.state = .active
        addSubview(material)
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold); titleLabel.textColor = Theme.primary; addSubview(titleLabel)
        settingsButton = NSButton(image: NSImage(systemSymbolName: "ellipsis", accessibilityDescription: L("Settings"))!, target: self, action: #selector(settingsClicked(_:)))
        settingsButton.isBordered = false; settingsButton.contentTintColor = Theme.secondary
        settingsButton.setAccessibilityLabel(L("Settings")); settingsButton.setAccessibilityHelp(L("Open settings. Keyboard shortcut Command Comma.")); addSubview(settingsButton)
        addSubview(pinnedSection); addSubview(recentSection)
        footer.font = .systemFont(ofSize: 11); footer.textColor = Theme.secondary; footer.lineBreakMode = .byTruncatingTail; addSubview(footer)
        undoButton.isBordered = false; undoButton.contentTintColor = Theme.accent
        undoButton.target = self; undoButton.action = #selector(undoClicked); undoButton.isHidden = true; addSubview(undoButton)
        trash.isHidden = true; trash.setAccessibilityLabel(L("Trash — drop to delete")); addSubview(trash)
        refresh()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func draw(_ dirtyRect: NSRect) {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency { Theme.background.setFill(); bounds.fill() }
    }
    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance(); needsDisplay = true
        for button in buttons { button.needsDisplay = true }; lifted?.needsDisplay = true
    }
    func showUpdateAvailable(_ available: Bool) { /* Updates use Settings only, never a permanent footer. */ }
    @objc private func settingsClicked(_ sender: NSButton) { onSettings?(sender) }
    func refresh() {
        guard !dragging && !animating else { return }
        let focusedID = identities.indices.contains(selected) ? identities[selected].1 : nil
        let origin = pinnedSection.scroll.contentView.bounds.origin
        buttons = []; identities = []
        for item in store.sortedPins { makeRow(item, pinned: true) }
        let pinRows = buttons
        for item in store.recent { makeRow(item, pinned: false) }
        let recentRows = Array(buttons.dropFirst(pinRows.count))
        selected = focusedID.flatMap { id in identities.firstIndex(where: { $0.1 == id }) } ?? -1
        // Grow smoothly up to nine pins; thereafter only pins scroll. Recent copies remain visible.
        let desiredPinHeight = CGFloat(max(1, min(store.pinned.count, 9))) * 42 + 28
        let screenLimit = (window?.screen ?? NSScreen.main)?.visibleFrame.height ?? 900
        let pinHeight = min(desiredPinHeight, max(112, screenLimit - 382))
        let recentHeight: CGFloat = 154
        let height = pinHeight + recentHeight + 138
        setFrameSize(NSSize(width: 380, height: height))
        titleLabel.frame = NSRect(x: 20, y: height - 43, width: 280, height: 23)
        settingsButton.frame = NSRect(x: 332, y: height - 44, width: 28, height: 26)
        recentSection.frame = NSRect(x: 20, y: 48, width: 340, height: recentHeight)
        pinnedSection.frame = NSRect(x: 20, y: 224, width: 340, height: pinHeight)
        pinnedSection.arrange(pinRows, count: store.pinned.count); recentSection.arrange(recentRows, count: store.recent.count)
        let maxY = max(0, pinnedSection.document.bounds.height - pinnedSection.scroll.contentSize.height)
        pinnedSection.scroll.contentView.scroll(to: NSPoint(x: 0, y: min(origin.y, maxY)))
        pinnedSection.scroll.reflectScrolledClipView(pinnedSection.scroll.contentView)
        footer.frame = NSRect(x: 22, y: 15, width: undoButton.isHidden ? 336 : 274, height: 18)
        undoButton.frame = NSRect(x: 299, y: 10, width: 62, height: 28)
        if !dragging { trash.frame = NSRect(x: 285, y: bounds.height - 185, width: 52, height: 52) }
        if footer.stringValue.isEmpty { footer.stringValue = L("Pins copy · Recent copies pin") }
        if store.error != nil { footer.stringValue = L("Pins file unreadable. See Settings → About.") }
        updateFocus(); onResize?(frame.size)
    }
    private func makeRow(_ item: Snippet, pinned: Bool) {
        let text = item.text.components(separatedBy: .newlines).joined(separator: "  ")
        let button = SnippetRow(title: String(text.prefix(180)), target: self, action: #selector(rowClicked(_:)))
        button.isPinned = pinned; button.tag = buttons.count; button.isBordered = false
        button.setAccessibilityLabel(L(pinned ? "Copy pinned snippet" : "Pin recent copy") + ": " + String(text.prefix(180)))
        button.setAccessibilityHelp(L(pinned ? "Copy and drag help" : "Click to save as a pinned snippet."))
        button.dragAction = { [weak self] row, event in self?.drag(row, first: event) }
        buttons.append(button); identities.append((pinned, item.id))
    }
    @objc private func rowClicked(_ sender: SnippetRow) {
        guard !dragging && !animating, buttons.contains(where: { $0 === sender }) else { return }
        selected = sender.tag; activateSelection(); window?.makeFirstResponder(self)
    }
    private func activateSelection() {
        guard !dragging && !animating, identities.indices.contains(selected) else { return }
        let (pin, id) = identities[selected]
        if pin, let item = store.pinned.first(where: { $0.id == id }) {
            guard onCopy?(item.text) == true else { footer.stringValue = L("Could not copy. Try again."); return }
            _ = store.recordCopy(id)
            onClose?() // Successful pasteboard write closes immediately; ranking refreshes next open.
        } else {
            if store.recent.first(where: { $0.id == id }).map({ recent in store.pinned.contains(where: { $0.text == recent.text }) }) == true {
                footer.stringValue = L("Already pinned"); return
            }
            guard store.pin(id) else { footer.stringValue = L("Could not save pin. Check storage permissions."); return }
            footer.stringValue = L("Pinned")
            let source = buttons[selected]
            let start = source.convert(source.bounds, to: self)
            refresh()
            guard let destinationIndex = identities.firstIndex(where: { $0.0 && $0.1 == id }) else { return }
            let destination = buttons[destinationIndex]
            destination.scrollToVisible(destination.bounds)
            let target = destination.convert(destination.bounds, to: self)
            let preview = floatingBubble(title: source.title, frame: start)
            destination.alphaValue = 0.35; animating = true
            NSAnimationContext.runAnimationGroup { context in
                context.duration = reduceMotion ? 0 : 0.22
                preview.animator().frame = target
                destination.animator().alphaValue = 1
            } completionHandler: { [weak self, weak preview] in preview?.removeFromSuperview(); self?.animating = false; self?.refresh() }
        }
        updateFocus()
    }
    private func floatingBubble(title: String, frame: NSRect) -> SnippetRow {
        let preview = SnippetRow(title: title, target: nil, action: nil)
        preview.isPinned = true; preview.frame = frame; preview.wantsLayer = true
        preview.shadow = NSShadow(); preview.shadow?.shadowColor = NSColor.black.withAlphaComponent(0.25)
        preview.shadow?.shadowBlurRadius = 12; preview.shadow?.shadowOffset = NSSize(width: 0, height: -3)
        preview.setAccessibilityElement(false); addSubview(preview, positioned: .below, relativeTo: trash); return preview
    }
    private func removePin(_ id: UUID, row: SnippetRow?) {
        guard store.delete(id) else { footer.stringValue = L("Could not save deletion. Pin was kept."); return }
        footer.stringValue = L("Deleted"); undoButton.isHidden = false
        undoTimer?.invalidate(); undoTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            self?.undoButton.isHidden = true; self?.footer.stringValue = L("Pins copy · Recent copies pin"); self?.refresh()
        }
        animating = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = reduceMotion ? 0 : 0.16
            row?.animator().alphaValue = 0
            if let row, !reduceMotion { row.animator().frame.size.height = 0 }
        } completionHandler: { [weak self] in self?.animating = false; self?.refresh() }
    }
    @objc private func undoClicked() {
        guard !dragging && !animating else { return }
        store.undoDelete(); undoButton.isHidden = !store.canUndo
        footer.stringValue = L(store.canUndo ? "Could not undo deletion." : "Restored")
        undoTimer?.invalidate(); refresh()
    }
    private func drag(_ row: SnippetRow, first: NSEvent) {
        guard !animating, identities.indices.contains(row.tag), identities[row.tag].0 else { return }
        let id = identities[row.tag].1
        dragging = true
        let sourceFrame = row.convert(row.bounds, to: self)
        let preview = floatingBubble(title: row.title, frame: sourceFrame); lifted = preview; row.placeholder = true
        let initial = convert(row.dragOriginInWindow ?? first.locationInWindow, from: nil)
        positionTrash(near: initial, source: sourceFrame)
        showDeletionTarget(true)
        let offset = NSPoint(x: initial.x - sourceFrame.minX, y: initial.y - sourceFrame.minY)
        defer { preview.removeFromSuperview(); lifted = nil; row.placeholder = false; dragging = false; showDeletionTarget(false); refresh() }
        var event = first
        while true {
            let point = convert(event.locationInWindow, from: nil)
            preview.frame.origin = NSPoint(x: point.x - offset.x, y: point.y - offset.y)
            let inside = trash.frame.contains(point); trash.highlighted = inside
            if event.type == .leftMouseUp {
                if inside { removePin(id, row: row) } else { footer.stringValue = L("Deletion cancelled") }
                return
            }
            if event.type == .keyDown && event.keyCode == 53 { footer.stringValue = L("Deletion cancelled"); return }
            guard let next = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp, .keyDown]) else { return }
            event = next
        }
    }
    private func updateFocus() {
        for (index, button) in buttons.enumerated() { button.state = index == selected ? .on : .off; button.needsDisplay = true }
    }
    override func keyDown(with event: NSEvent) {
        guard !animating && !dragging else { return }
        if event.modifierFlags.contains(.command) {
            if event.charactersIgnoringModifiers == "z" { undoClicked(); return }
            if event.charactersIgnoringModifiers == "," { onSettings?(settingsButton); return }
            if event.charactersIgnoringModifiers == "q" { NSApp.terminate(nil); return }
        }
        switch event.keyCode {
        case 125, 48: selected = buttons.isEmpty ? -1 : (selected + (event.modifierFlags.contains(.shift) ? buttons.count - 1 : 1) + buttons.count) % buttons.count
        case 126: selected = buttons.isEmpty ? -1 : max(0, selected - 1)
        case 36, 49: activateSelection(); return
        case 53: onClose?(); return
        case 51, 117:
            if event.modifierFlags.contains(.command), identities.indices.contains(selected), identities[selected].0 {
                let id = identities[selected].1
                let alert = NSAlert(); alert.messageText = L("Delete selected pinned snippet?")
                alert.informativeText = L("You can undo this from Settings until the next deletion.")
                alert.addButton(withTitle: L("Cancel")); alert.addButton(withTitle: L("Delete"))
                if alert.runModal() == .alertSecondButtonReturn { removePin(id, row: buttons[selected]) }
            }
            return
        default: super.keyDown(with: event); return
        }
        updateFocus()
        if buttons.indices.contains(selected) { buttons[selected].scrollToVisible(buttons[selected].bounds) }
    }
    private func positionTrash(near point: NSPoint, source: NSRect) {
        // Stable throughout a drag. Choose the reachable side, clamp inside the popover.
        trash.frame = DragTargetGeometry.target(origin: point, source: source, bounds: bounds)
    }
    func showDeletionTarget(_ visible: Bool) {
        trash.isHidden = !visible; footer.isHidden = visible; undoButton.isHidden = visible || !store.canUndo; trash.highlighted = false
    }
    // Synthetic previews exercise the same drawing and placeholder as the real local drag.
    func previewDrag() {
        guard let row = buttons.first else { return }
        let source = row.convert(row.bounds, to: self)
        positionTrash(near: NSPoint(x: 225, y: source.midY), source: source)
        showDeletionTarget(true); row.placeholder = true
        lifted = floatingBubble(title: row.title, frame: source.offsetBy(dx: -12, dy: -16))
        trash.highlighted = true
    }
    func capture(to url: URL) {
        layoutSubtreeIfNeeded()
        guard let rep = bitmapImageRepForCachingDisplay(in: bounds) else { return }
        cacheDisplay(in: bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
