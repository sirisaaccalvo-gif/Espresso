import AppKit

/// The full-color **Espresso mascot** — a little cup with a face. Used for the app
/// icon, About panel, and App Store screenshots. (The *menu-bar* glyph stays the
/// clean monochrome template cup in `CupIconRenderer`; this is the cute character.)
enum MascotRenderer {

    /// Render to an exact pixel-size PNG (proper alpha), used for the .iconset and previews.
    static func png(pixels: Int, awake: Bool, background: Bool) -> Data? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
            let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        ctx.imageInterpolation = .high
        draw(size: CGFloat(pixels), awake: awake, background: background)
        ctx.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }

    // Authored in a unit square scaled by `s`. AppKit default coords: y points up.
    private static func draw(size s: CGFloat, awake: Bool, background: Bool) {
        func P(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x * s, y: y * s) }
        func RR(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
            NSRect(x: x * s, y: y * s, width: w * s, height: h * s)
        }

        let ink       = NSColor(srgbRed: 0.20, green: 0.12, blue: 0.07, alpha: 1)
        let porcelain = NSColor(srgbRed: 0.99, green: 0.97, blue: 0.93, alpha: 1)
        let crema     = NSColor(srgbRed: 0.78, green: 0.52, blue: 0.30, alpha: 1)
        let cheek     = NSColor(srgbRed: 0.96, green: 0.62, blue: 0.58, alpha: 0.85)
        let lw = max(1.0, 0.016 * s)

        // Warm rounded-square background.
        if background {
            let bg = NSBezierPath(roundedRect: RR(0.045, 0.045, 0.91, 0.91),
                                  xRadius: 0.225 * s, yRadius: 0.225 * s)
            NSGradient(colors: [NSColor(srgbRed: 0.98, green: 0.90, blue: 0.78, alpha: 1),
                                NSColor(srgbRed: 0.91, green: 0.76, blue: 0.57, alpha: 1)])?
                .draw(in: bg, angle: -90)
        }

        // Steam (behind the cup) — only when awake.
        if awake {
            NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.6).setStroke()
            for x0 in [CGFloat(0.42), 0.50, 0.58] {
                let p = NSBezierPath()
                p.move(to: P(x0, 0.68))
                p.curve(to: P(x0, 0.87), controlPoint1: P(x0 + 0.05, 0.73), controlPoint2: P(x0 - 0.05, 0.81))
                p.lineWidth = 0.022 * s
                p.lineCapStyle = .round
                p.stroke()
            }
        }

        // Saucer.
        let saucer = NSBezierPath(ovalIn: RR(0.18, 0.175, 0.64, 0.13))
        porcelain.setFill(); saucer.fill()
        ink.setStroke(); saucer.lineWidth = lw; saucer.stroke()

        // Handle (drawn before the body so the body overlaps its join).
        let handle = NSBezierPath()
        handle.appendArc(withCenter: P(0.745, 0.49), radius: 0.105 * s, startAngle: -78, endAngle: 78)
        handle.lineWidth = 0.055 * s
        ink.setStroke(); handle.stroke()

        // Cup body.
        let cup = NSBezierPath()
        cup.move(to: P(0.285, 0.64))
        cup.curve(to: P(0.40, 0.27), controlPoint1: P(0.285, 0.45), controlPoint2: P(0.33, 0.30))
        cup.curve(to: P(0.60, 0.27), controlPoint1: P(0.46, 0.24), controlPoint2: P(0.54, 0.24))
        cup.curve(to: P(0.715, 0.64), controlPoint1: P(0.67, 0.30), controlPoint2: P(0.715, 0.45))
        cup.close()
        porcelain.setFill(); cup.fill()

        // Crema at the rim (clipped to the cup).
        NSGraphicsContext.saveGraphicsState()
        cup.addClip()
        crema.setFill()
        NSBezierPath(ovalIn: RR(0.285, 0.595, 0.43, 0.085)).fill()
        NSGraphicsContext.restoreGraphicsState()

        ink.setStroke(); cup.lineWidth = lw; cup.stroke()

        // Cheeks.
        cheek.setFill()
        NSBezierPath(ovalIn: RR(0.345, 0.40, 0.08, 0.052)).fill()
        NSBezierPath(ovalIn: RR(0.575, 0.40, 0.08, 0.052)).fill()

        // Face.
        let eyeW: CGFloat = 0.075, eyeH: CGFloat = 0.105, eyeY: CGFloat = 0.45
        let lx: CGFloat = 0.40, rx: CGFloat = 0.525
        if awake {
            for ex in [lx, rx] {
                let white = NSBezierPath(ovalIn: RR(ex, eyeY, eyeW, eyeH))
                NSColor.white.setFill(); white.fill()
                ink.setStroke(); white.lineWidth = lw * 0.7; white.stroke()
                let pup = NSBezierPath(ovalIn: RR(ex + eyeW * 0.30, eyeY + eyeH * 0.18, eyeW * 0.45, eyeH * 0.45))
                ink.setFill(); pup.fill()
                let hi = NSBezierPath(ovalIn: RR(ex + eyeW * 0.36, eyeY + eyeH * 0.44, eyeW * 0.17, eyeH * 0.17))
                NSColor.white.setFill(); hi.fill()
            }
            let smile = NSBezierPath()
            smile.appendArc(withCenter: P(0.5, 0.405), radius: 0.05 * s, startAngle: 205, endAngle: 335)
            smile.lineWidth = lw; smile.lineCapStyle = .round
            ink.setStroke(); smile.stroke()
        } else {
            ink.setStroke()
            // Calm closed eyes (gentle downward curves).
            for ex in [lx, rx] {
                let e = NSBezierPath()
                e.appendArc(withCenter: P(ex + eyeW / 2, eyeY + eyeH * 0.55), radius: 0.045 * s,
                            startAngle: 200, endAngle: 340)
                e.lineWidth = lw; e.lineCapStyle = .round; e.stroke()
            }
            // Small peaceful smile (not a frown).
            let mouth = NSBezierPath()
            mouth.appendArc(withCenter: P(0.5, 0.405), radius: 0.022 * s, startAngle: 210, endAngle: 330)
            mouth.lineWidth = lw; mouth.lineCapStyle = .round
            ink.setStroke(); mouth.stroke()
            // Floating "z z z" to signal napping.
            let zs: [(CGFloat, CGFloat, CGFloat)] = [(0.62, 0.60, 0.055), (0.685, 0.67, 0.07), (0.76, 0.75, 0.09)]
            for (zx, zy, zsize) in zs {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.boldSystemFont(ofSize: zsize * s),
                    .foregroundColor: ink,
                ]
                ("z" as NSString).draw(at: P(zx, zy), withAttributes: attrs)
            }
        }
    }
}

/// `--make-icon <dir>`: writes preview PNGs plus a full `AppIcon.iconset` for `iconutil`.
enum AppIconExport {
    @MainActor
    static func run(dir: String) -> Never {
        _ = NSApplication.shared
        let fm = FileManager.default
        let iconset = "\(dir)/AppIcon.iconset"
        try? fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)

        // Previews for visual review.
        write(MascotRenderer.png(pixels: 512, awake: true, background: true), "\(dir)/preview_awake.png")
        write(MascotRenderer.png(pixels: 512, awake: false, background: true), "\(dir)/preview_sleepy.png")

        // .iconset members (name, pixels).
        let members: [(String, Int)] = [
            ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
        ]
        for (name, px) in members {
            write(MascotRenderer.png(pixels: px, awake: true, background: true), "\(iconset)/\(name)")
        }
        print("Wrote previews + \(iconset)")
        exit(0)
    }

    private static func write(_ data: Data?, _ path: String) {
        guard let data else { return }
        try? data.write(to: URL(fileURLWithPath: path))
    }
}
