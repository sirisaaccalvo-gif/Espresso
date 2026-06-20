import AppKit
import EspressoKit

/// `--make-screenshots <dir>`: renders a branded App Store screenshot set (2560×1600, 16:10).
/// Programmatic so the set stays consistent and high-res; reuses the mascot + cup art.
@MainActor
enum ScreenshotRenderer {
    static let W: CGFloat = 2560
    static let H: CGFloat = 1600

    static func make(dir: String) -> Never {
        _ = NSApplication.shared
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let shots: [(String, (NSRect) -> Void)] = [
            ("01_hero", drawHero),
            ("02_brews", drawBrews),
            ("03_drain", drawDrain),
            ("04_battery", drawBattery),
            ("05_offmeansoff", drawOff),
        ]
        for (name, draw) in shots {
            writePNG(render(draw), to: "\(dir)/\(name).png")
        }
        print("Wrote \(shots.count) screenshots to \(dir)")
        exit(0)
    }

    // MARK: - Palette / type

    private static let espresso = NSColor(srgbRed: 0.20, green: 0.12, blue: 0.07, alpha: 1)
    private static let brown    = NSColor(srgbRed: 0.42, green: 0.29, blue: 0.18, alpha: 1)
    private static let accent   = NSColor(srgbRed: 0.0, green: 0.48, blue: 1.0, alpha: 1)

    private static func render(_ draw: (NSRect) -> Void) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        draw(NSRect(x: 0, y: 0, width: W, height: H))
        NSGraphicsContext.current?.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    private static func background(_ rect: NSRect, top: NSColor, bottom: NSColor) {
        NSGradient(colors: [top, bottom])?.draw(in: rect, angle: -90)
    }

    /// Rect anchored from the TOP of the canvas (text/draw read top-down).
    private static func topRect(_ top: CGFloat, _ height: CGFloat, x: CGFloat = 0, width: CGFloat = W) -> NSRect {
        NSRect(x: x, y: H - top - height, width: width, height: height)
    }

    private static func string(_ s: String, size: CGFloat, weight: NSFont.Weight,
                               color: NSColor, in rect: NSRect, align: NSTextAlignment = .center) {
        let p = NSMutableParagraphStyle()
        p.alignment = align
        p.lineBreakMode = .byWordWrapping
        (s as NSString).draw(in: rect, withAttributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: p,
        ])
    }

    private static func mascot(awake: Bool, px: Int) -> NSImage {
        NSImage(data: MascotRenderer.png(pixels: px, awake: awake, background: false) ?? Data()) ?? NSImage()
    }

    /// Tinted (non-template) version of the menu-bar cup glyph.
    private static func tintedCup(fill: CGFloat, active: Bool, px: CGFloat, color: NSColor) -> NSImage {
        let glyph = CupIconRenderer.cupImage(fill: fill, active: active, size: px)
        let out = NSImage(size: NSSize(width: px, height: px))
        out.lockFocus()
        let r = NSRect(x: 0, y: 0, width: px, height: px)
        glyph.draw(in: r)
        color.set()
        r.fill(using: .sourceAtop)
        out.unlockFocus()
        return out
    }

    private static func wordmark() {
        string("☕ Espresso", size: 46, weight: .semibold, color: brown,
               in: topRect(H - 110, 70), align: .center)
    }

    // MARK: - Screens

    private static func drawHero(_ rect: NSRect) {
        background(rect, top: NSColor(srgbRed: 0.99, green: 0.93, blue: 0.83, alpha: 1),
                   bottom: NSColor(srgbRed: 0.90, green: 0.74, blue: 0.54, alpha: 1))
        let m = mascot(awake: true, px: 840)
        m.draw(in: NSRect(x: (W - 840) / 2, y: 210, width: 840, height: 840))
        string("Keep your Mac wide awake", size: 132, weight: .bold, color: espresso,
               in: topRect(130, 170))
        string("A cute little menu-bar app — one shot at a time.", size: 58, weight: .regular,
               color: brown, in: topRect(320, 80))
    }

    private static func drawBrews(_ rect: NSRect) {
        background(rect, top: NSColor(srgbRed: 0.97, green: 0.90, blue: 0.80, alpha: 1),
                   bottom: NSColor(srgbRed: 0.85, green: 0.67, blue: 0.46, alpha: 1))
        string("A brew for every focus", size: 116, weight: .bold, color: espresso, in: topRect(120, 150))
        string("Timed sessions named after the real thing.", size: 52, weight: .regular,
               color: brown, in: topRect(290, 70))

        // Submenu-style panel of brews.
        let brews = ["Ristretto · 15 min", "Espresso · 30 min", "Doppio · 1 hour",
                     "Lungo · 2 hours", "Americano · 5 hours", "Bottomless · no limit", "Custom brew…"]
        let rowH: CGFloat = 96, padX: CGFloat = 56, padY: CGFloat = 40
        let panelW: CGFloat = 980
        let panelH = rowH * CGFloat(brews.count) + padY * 2
        let panelX = (W - panelW) / 2
        let panelTop: CGFloat = 470
        let panel = NSBezierPath(roundedRect: topRect(panelTop, panelH, x: panelX, width: panelW),
                                 xRadius: 36, yRadius: 36)
        NSColor(srgbRed: 0.12, green: 0.12, blue: 0.13, alpha: 0.98).setFill(); panel.fill()

        for (i, b) in brews.enumerated() {
            let rowTop = panelTop + padY + CGFloat(i) * rowH
            let checked = b.hasPrefix("Americano")
            if checked {
                string("✓", size: 46, weight: .semibold, color: NSColor(white: 0.95, alpha: 1),
                       in: topRect(rowTop + 24, rowH, x: panelX + 36, width: 50), align: .left)
            }
            string(b, size: 46, weight: checked ? .semibold : .regular,
                   color: NSColor(white: 0.95, alpha: 1),
                   in: topRect(rowTop + 24, rowH, x: panelX + padX + 60, width: panelW - padX - 80), align: .left)
        }
        wordmark()
    }

    private static func drawDrain(_ rect: NSRect) {
        background(rect, top: NSColor(srgbRed: 0.98, green: 0.92, blue: 0.82, alpha: 1),
                   bottom: NSColor(srgbRed: 0.88, green: 0.71, blue: 0.50, alpha: 1))
        string("Watch the crema drain", size: 124, weight: .bold, color: espresso, in: topRect(130, 160))
        string("The cup empties as your timer runs down — time left, at a glance.",
               size: 52, weight: .regular, color: brown, in: topRect(300, 70))

        // Row of cups draining left → right.
        let fills: [CGFloat] = [1.0, 0.66, 0.33, 0.0]
        let cupPx: CGFloat = 300
        let gap: CGFloat = 120
        let totalW = CGFloat(fills.count) * cupPx + CGFloat(fills.count - 1) * gap
        var x = (W - totalW) / 2
        for f in fills {
            let cup = tintedCup(fill: f, active: f > 0, px: cupPx, color: espresso)
            cup.draw(in: NSRect(x: x, y: 560, width: cupPx, height: cupPx))
            x += cupPx + gap
        }
        // Arrow caption (below the cups).
        string("full  →  empty", size: 44, weight: .medium, color: brown, in: topRect(1110, 60))
        wordmark()
    }

    private static func drawBattery(_ rect: NSRect) {
        background(rect, top: NSColor(srgbRed: 0.97, green: 0.91, blue: 0.81, alpha: 1),
                   bottom: NSColor(srgbRed: 0.86, green: 0.69, blue: 0.48, alpha: 1))
        string("Battery-smart safety", size: 124, weight: .bold, color: espresso, in: topRect(130, 160))
        string("On battery and running low? Espresso lets your Mac nap —\nat a threshold you choose.",
               size: 54, weight: .regular, color: brown, in: topRect(300, 150))

        let m = mascot(awake: false, px: 560)
        m.draw(in: NSRect(x: (W - 560) / 2, y: 360, width: 560, height: 560))

        // Little low-battery pill.
        let pillW: CGFloat = 880, pillH: CGFloat = 120
        let pill = NSBezierPath(roundedRect: NSRect(x: (W - pillW) / 2, y: 250, width: pillW, height: pillH),
                                xRadius: 60, yRadius: 60)
        NSColor(srgbRed: 0.12, green: 0.12, blue: 0.13, alpha: 0.96).setFill(); pill.fill()
        string("🪫  Napped to save battery (20%)", size: 40, weight: .semibold,
               color: NSColor(white: 0.96, alpha: 1),
               in: NSRect(x: (W - pillW) / 2, y: 250 + (pillH - 52) / 2 - 4, width: pillW, height: 52))
        wordmark()
    }

    private static func drawOff(_ rect: NSRect) {
        background(rect, top: NSColor(srgbRed: 0.96, green: 0.90, blue: 0.82, alpha: 1),
                   bottom: NSColor(srgbRed: 0.83, green: 0.66, blue: 0.47, alpha: 1))
        let m = mascot(awake: false, px: 680)
        m.draw(in: NSRect(x: (W - 680) / 2, y: 300, width: 680, height: 680))
        string("Off means off", size: 132, weight: .bold, color: espresso, in: topRect(140, 170))
        string("No Dock clutter. Lives quietly in your menu bar.", size: 56, weight: .regular,
               color: brown, in: topRect(330, 80))
    }

    private static func writePNG(_ rep: NSBitmapImageRep, to path: String) {
        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
        }
    }
}
