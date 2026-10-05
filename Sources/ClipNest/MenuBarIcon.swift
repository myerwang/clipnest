// The approved clipboard + shallow nest outline, drawn crisply at every display scale.
// Two horizontal text lines. A template image lets macOS choose the menu-bar tint.
import AppKit

enum MenuBarIcon {
    static func make() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            func stroke(_ path: NSBezierPath, width: CGFloat = 1.5) {
                path.lineWidth = width; path.lineCapStyle = .round; path.lineJoinStyle = .round; path.stroke()
            }
            let body = NSBezierPath()
            body.move(to: NSPoint(x: 4, y: 4.6)); body.line(to: NSPoint(x: 4, y: 13.2))
            body.curve(to: NSPoint(x: 5.2, y: 14.4), controlPoint1: NSPoint(x: 4, y: 14), controlPoint2: NSPoint(x: 4.4, y: 14.4))
            body.line(to: NSPoint(x: 7.2, y: 14.4)); stroke(body)
            let right = NSBezierPath()
            right.move(to: NSPoint(x: 10.8, y: 14.4)); right.line(to: NSPoint(x: 12.8, y: 14.4))
            right.curve(to: NSPoint(x: 14, y: 13.2), controlPoint1: NSPoint(x: 13.6, y: 14.4), controlPoint2: NSPoint(x: 14, y: 14))
            right.line(to: NSPoint(x: 14, y: 4.6)); stroke(right)
            stroke(NSBezierPath(roundedRect: NSRect(x: 7.2, y: 13.6, width: 3.6, height: 2.9), xRadius: 0.5, yRadius: 0.5), width: 1.4)
            // Preserve two distinct lines even at native 18pt size.
            for y: CGFloat in [10.5, 7.5] {
                let line = NSBezierPath(); line.move(to: NSPoint(x: 6.8, y: y)); line.line(to: NSPoint(x: 11.2, y: y)); stroke(line, width: 1.4)
            }
            let nest = NSBezierPath(); nest.move(to: NSPoint(x: 1.7, y: 5.8)); nest.line(to: NSPoint(x: 1.7, y: 4.3))
            nest.curve(to: NSPoint(x: 4, y: 2), controlPoint1: NSPoint(x: 1.7, y: 2.7), controlPoint2: NSPoint(x: 2.5, y: 2))
            nest.line(to: NSPoint(x: 14, y: 2))
            nest.curve(to: NSPoint(x: 16.3, y: 4.3), controlPoint1: NSPoint(x: 15.5, y: 2), controlPoint2: NSPoint(x: 16.3, y: 2.7))
            nest.line(to: NSPoint(x: 16.3, y: 5.8)); stroke(nest)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "ClipNest clipboard with two lines and a nest"
        return image
    }
}
