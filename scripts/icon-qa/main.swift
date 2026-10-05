import AppKit
let app = NSApplication.shared; app.setActivationPolicy(.accessory)
let root = URL(fileURLWithPath: ProcessInfo.processInfo.environment["CLIPNEST_ICON_QA_DIR"] ?? "/tmp/clipnest-icon-qa-output")
func export(_ image: NSImage, name: String, size: Int, background: NSColor) {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    background.setFill(); NSRect(x: 0, y: 0, width: size, height: size).fill()
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    try! bitmap.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent(name))
}
let icon = NSWorkspace.shared.icon(forFile: root.appendingPathComponent("ClipNest-candidate.app").path)
export(icon, name: "Finder-icon-on-dark.png", size: 256, background: NSColor(srgbRed: 0.15, green: 0.17, blue: 0.2, alpha: 1))
let template = MenuBarIcon.make()
precondition(template.isTemplate && template.size == NSSize(width: 18, height: 18))
for (name, appearance, tint) in [("light", NSAppearance.Name.aqua, NSColor.black), ("dark", .darkAqua, NSColor.white)] {
    let view = NSImageView(frame: NSRect(x: 0, y: 0, width: 18, height: 18))
    view.image = template; view.imageScaling = .scaleNone; view.contentTintColor = tint; view.appearance = NSAppearance(named: appearance)
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 36, pixelsHigh: 36, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    bitmap.size = NSSize(width: 18, height: 18)
    view.cacheDisplay(in: view.bounds, to: bitmap)
    try! bitmap.representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("menu-template-\(name)@2x.png"))
    let large = NSImage(size: NSSize(width: 180, height: 180)); large.addRepresentation(bitmap)
    export(large, name: "menu-template-\(name)-enlarged.png", size: 180, background: name == "dark" ? .darkGray : .white)
}
print("PASS: actual NSWorkspace icon export and 18pt template light/dark renders; two source paths for text lines")
