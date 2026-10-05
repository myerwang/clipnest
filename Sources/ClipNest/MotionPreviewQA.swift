// Responsibility: offscreen native synthetic comparisons; never activates a window or touches user clipboard/preferences.
// Development status: complete.
import AppKit
import ClipNestCore

final class MotionPreviewQA {
    let root: URL
    let panel: PanelView
    let window: NSWindow
    let states = ["Idle", "Drag", "Fold", "Restored"]
    var index = 0
    var pictures: [NSImage] = []
    init() {
        precondition(Bundle.main.bundleIdentifier?.hasSuffix(".qa") == true)
        root = URL(fileURLWithPath: ProcessInfo.processInfo.environment["CLIPNEST_QA_DIR"] ?? NSTemporaryDirectory() + "clipnest-motion-previews")
        try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = ClipboardStore(file: root.appendingPathComponent("synthetic-pins.json"))
        for text in ["A small, clear clipboard helper", "Project notes — keep it simple", "Thanks — I will take a look today"] {
            store.ingest(text); _ = store.pin(store.recent[0].id)
        }
        store.ingest("A new synthetic copy to keep")
        panel = PanelView(store: store)
        window = NSWindow(contentRect: NSRect(x: -12000, y: -12000, width: panel.frame.width, height: panel.frame.height), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = panel; window.isReleasedWhenClosed = false
        window.title = "ClipNest offscreen synthetic motion preview"
        window.orderBack(nil) // Offscreen and never key; no frontmost activation or status item.
    }
    func start() { next() }
    func next() {
        guard index < 8 else { finish(); return }
        let dark = index >= 4, state = index % 4
        panel.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        panel.previewDragEnded()
        if state == 1 || state == 2 { panel.previewDrag(highlighted: state == 2) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [self] in
            let name = "ClipNest-" + (dark ? "Dark-" : "Light-") + states[state] + ".png"
            let url = root.appendingPathComponent(name)
            panel.capture(to: url)
            guard let image = NSImage(contentsOf: url) else { fatalError("Native preview capture failed") }
            pictures.append(image); index += 1; next()
        }
    }
    func finish() {
        let tile = panel.frame.size, gap: CGFloat = 16, label: CGFloat = 30
        let canvas = NSImage(size: NSSize(width: tile.width * 4 + gap * 5, height: (tile.height + label) * 2 + gap * 3))
        canvas.lockFocus()
        NSColor(srgbRed: 0.93, green: 0.94, blue: 0.96, alpha: 1).setFill()
        NSRect(origin: .zero, size: canvas.size).fill()
        for (i, picture) in pictures.enumerated() {
            let x = gap + CGFloat(i % 4) * (tile.width + gap)
            let y = gap + CGFloat(1 - i / 4) * (tile.height + label + gap)
            picture.draw(in: NSRect(x: x, y: y, width: tile.width, height: tile.height))
            let caption = (i < 4 ? "Light" : "Dark") + " · " + states[i % 4]
            (caption as NSString).draw(in: NSRect(x: x, y: y + tile.height + 7, width: tile.width, height: 18), withAttributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor.black])
        }
        canvas.unlockFocus()
        let rep = NSBitmapImageRep(data: canvas.tiffRepresentation!)!
        try! rep.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("ClipNest-Trash-Native-Comparison.png"))
        print("PASS: eight native offscreen synthetic states plus comparison; no mouse interaction, general pasteboard or system setting changes")
        window.orderOut(nil); NSApp.terminate(nil)
    }
}

func motionPreviewQA() {
    let app = NSApplication.shared; app.setActivationPolicy(.accessory)
    let preview = MotionPreviewQA(); preview.start()
    withExtendedLifetime(preview) { app.run() }
}
