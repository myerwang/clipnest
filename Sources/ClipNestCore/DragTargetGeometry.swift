// Responsibility: a nearby, stable trash target clamped to the menu bar panel.
// Development status: complete.
import Foundation
import CoreGraphics
public enum DragTargetGeometry {
    public static func target(origin: CGPoint, source: CGRect, bounds: CGRect) -> CGRect {
        let centerX = origin.x + 72 <= bounds.maxX - 34 ? origin.x + 72 : origin.x - 72
        let centerY = source.midY - 52 >= bounds.minY + 36 ? source.midY - 52 : source.midY + 52
        return CGRect(x: min(max(bounds.minX + 12, centerX - 26), bounds.maxX - 64),
                      y: min(max(bounds.minY + 12, centerY - 26), bounds.maxY - 64), width: 52, height: 52)
    }
}
