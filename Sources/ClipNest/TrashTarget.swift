// Responsibility: a quiet glass trash target with a stable 52pt hit area and brief visual feedback.
// Relationship: PanelView positions it once per drag; visual animations never move the hit target.
// Development status: complete.
import AppKit
import QuartzCore

final class TrashTarget: NSView {
    private let disc = NSView()
    private let material = NSVisualEffectView()
    private let wash = NSView()
    private let icon = NSImageView()
    private var generation = 0
    private var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    var highlighted = false { didSet { if oldValue != highlighted { updateStyle(animated: true) } } }
    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true; disc.wantsLayer = true; addSubview(disc)
        disc.shadow = NSShadow(); disc.shadow?.shadowBlurRadius = 7
        disc.shadow?.shadowOffset = NSSize(width: 0, height: -2)
        material.wantsLayer = true; material.material = .popover
        material.blendingMode = .withinWindow; material.state = .active
        disc.addSubview(material)
        wash.wantsLayer = true; disc.addSubview(wash)
        icon.image = NSImage(systemSymbolName: "trash", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 17, weight: .regular))
        icon.imageScaling = .scaleProportionallyUpOrDown; disc.addSubview(icon)
        isHidden = true; updateStyle(animated: false)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() { super.layout(); updateGeometry() }
    private func updateGeometry() {
        material.frame = disc.bounds; wash.frame = disc.bounds
        icon.frame = NSRect(x: (disc.bounds.width - 18) / 2, y: (disc.bounds.height - 20) / 2, width: 18, height: 20)
        for view in [material, wash] { view.layer?.cornerRadius = disc.bounds.width / 2; view.layer?.masksToBounds = true }
        disc.layer?.cornerRadius = disc.bounds.width / 2
    }
    private var restingFrame: NSRect {
        let inset: CGFloat = highlighted ? 4 : 6
        let side = max(0, min(bounds.width, bounds.height) - inset * 2)
        return NSRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side)
    }
    private func updateStyle(animated: Bool) {
        let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let danger = NSColor(srgbRed: dark ? 1 : 0.77, green: dark ? 0.48 : 0.22, blue: dark ? 0.48 : 0.28, alpha: 1)
        let reducedTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        icon.contentTintColor = highlighted ? danger : .secondaryLabelColor
        material.isHidden = reducedTransparency
        wash.layer?.backgroundColor = (highlighted ? danger.withAlphaComponent(reducedTransparency ? 0.17 : 0.13)
            : (reducedTransparency ? NSColor.windowBackgroundColor : NSColor.white.withAlphaComponent(dark ? 0.06 : 0.15))).cgColor
        disc.layer?.borderWidth = 0.5
        disc.layer?.borderColor = (highlighted ? danger.withAlphaComponent(0.4) : NSColor.white.withAlphaComponent(dark ? 0.2 : 0.7)).cgColor
        disc.shadow?.shadowColor = NSColor.black.withAlphaComponent(dark ? 0.2 : 0.12)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = animated && !isHidden && !reduceMotion ? 0.12 : 0
            disc.animator().frame = restingFrame
        }
        updateGeometry()
    }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); updateStyle(animated: false) }
    func reveal(animated: Bool = true) {
        generation += 1; highlighted = false; isHidden = false
        updateStyle(animated: false)
        if animated && !reduceMotion { disc.frame = restingFrame.insetBy(dx: 3, dy: 3) }
        disc.alphaValue = animated ? 0 : 1; updateGeometry()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = animated ? (reduceMotion ? 0.08 : 0.14) : 0
            disc.animator().alphaValue = 1; disc.animator().frame = restingFrame
        }
    }
    func dismiss(animated: Bool = true) {
        generation += 1; let token = generation
        NSAnimationContext.runAnimationGroup { context in
            context.duration = animated ? (reduceMotion ? 0.08 : 0.14) : 0
            disc.animator().alphaValue = 0
            if !reduceMotion { disc.animator().frame = restingFrame.insetBy(dx: 4, dy: 4) }
        } completionHandler: { [weak self] in
            guard let self, self.generation == token else { return }
            self.isHidden = true; self.highlighted = false
        }
    }
    func setPreview(highlighted: Bool, visible: Bool = true) {
        generation += 1; isHidden = !visible; self.highlighted = highlighted
        disc.alphaValue = 1; updateStyle(animated: false); layoutSubtreeIfNeeded()
    }
}
