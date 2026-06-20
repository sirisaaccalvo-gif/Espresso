import AppKit

/// Draws the menu-bar espresso cup as a **template** image (monochrome stencil that
/// macOS tints for light/dark menu bars). State is conveyed by shape/fill, never
/// color: inactive = outline only; active = filled "crema" that drains with `fill`.
enum CupIconRenderer {

    /// - Parameters:
    ///   - fill: 0...1 crema level (1 = full session remaining). 0 with `active == false`
    ///           renders an empty outline cup (the idle state).
    ///   - active: whether keep-awake is on (adds steam wisps).
    ///   - size: pixel size of the square image (18 pt in the menu bar; larger for export).
    static func cupImage(fill: CGFloat, active: Bool, size: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        defer { image.unlockFocus() }
        let transform = NSAffineTransform()
        transform.scale(by: size / 18.0)
        transform.concat()
        drawCup(fill: fill, active: active)
        image.isTemplate = true
        return image
    }

    // All geometry is authored in an 18x18 coordinate space and scaled by the caller.
    private static func drawCup(fill: CGFloat, active: Bool) {
        NSColor.black.setStroke()
        NSColor.black.setFill()
        let lineWidth: CGFloat = 1.3

        // Cup body: a gently tapering vessel with a rounded bottom.
        let left: CGFloat = 4.0
        let right: CGFloat = 12.0
        let top: CGFloat = 13.0
        let bottom: CGFloat = 5.0

        let body = NSBezierPath()
        body.move(to: NSPoint(x: left, y: top))
        body.line(to: NSPoint(x: right, y: top))
        body.line(to: NSPoint(x: right - 1.0, y: bottom + 1.6))
        body.curve(to: NSPoint(x: left + 1.0, y: bottom + 1.6),
                   controlPoint1: NSPoint(x: right - 1.3, y: bottom),
                   controlPoint2: NSPoint(x: left + 1.3, y: bottom))
        body.close()
        body.lineWidth = lineWidth
        body.lineJoinStyle = .round

        // Crema fill — clipped to the cup interior, rising from the bottom.
        let clamped = max(0.0, min(1.0, fill))
        if clamped > 0.001 {
            let interiorBottom: CGFloat = bottom + 1.4
            let interiorTop: CGFloat = top - 1.1
            let fillHeight = (interiorTop - interiorBottom) * clamped
            let fillRect = NSRect(x: left - 1.0,
                                  y: interiorBottom,
                                  width: (right - left) + 2.0,
                                  height: fillHeight)
            NSGraphicsContext.saveGraphicsState()
            body.addClip()
            NSBezierPath(rect: fillRect).fill()
            NSGraphicsContext.restoreGraphicsState()
        }

        // Handle on the right.
        let handleCenter = NSPoint(x: right + 0.4, y: (top + bottom) / 2.0 + 0.8)
        let handle = NSBezierPath()
        handle.appendArc(withCenter: handleCenter, radius: 2.5,
                         startAngle: -72, endAngle: 72)
        handle.lineWidth = lineWidth

        // Saucer line beneath the cup.
        let saucer = NSBezierPath()
        saucer.move(to: NSPoint(x: left - 1.6, y: bottom - 0.6))
        saucer.line(to: NSPoint(x: right + 1.6, y: bottom - 0.6))
        saucer.lineWidth = lineWidth
        saucer.lineCapStyle = .round

        body.stroke()
        handle.stroke()
        saucer.stroke()

        // Steam wisps when active.
        if active {
            for x in [CGFloat(6.4), CGFloat(9.2)] {
                let steam = NSBezierPath()
                steam.move(to: NSPoint(x: x, y: top + 1.0))
                steam.curve(to: NSPoint(x: x, y: top + 4.2),
                            controlPoint1: NSPoint(x: x + 1.6, y: top + 2.0),
                            controlPoint2: NSPoint(x: x - 1.6, y: top + 3.2))
                steam.lineWidth = 1.0
                steam.lineCapStyle = .round
                steam.stroke()
            }
        }
    }
}
