import AppKit
import EspressoKit

#if ESPRESSO_DEVTOOLS

/// `--selftest`: exercises the IOKit assertion path headlessly and prints the
/// relevant `pmset -g assertions` lines before/after, so the core sleep-prevention
/// mechanism can be verified from the command line without driving the menu UI.
enum SelfTest {
    static func run() -> Never {
        let controller = KeepAwakeController()
        print("Espresso self-test")
        printAssertions(label: "BEFORE start")

        controller.start(keepDisplayAwake: true)
        printAssertions(label: "AFTER start (system + display)")

        Thread.sleep(forTimeInterval: 1.0)

        controller.stop()
        printAssertions(label: "AFTER stop")

        print("Self-test complete.")
        exit(0)
    }

    private static func printAssertions(label: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "assertions"]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            print("  (could not run pmset: \(error))")
            return
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let relevant = output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.contains("PreventUserIdle") }
        print("--- \(label) ---")
        if relevant.isEmpty {
            print("  (no PreventUserIdle assertions held)")
        } else {
            for line in relevant { print("  \(line)") }
        }
    }
}

/// `--render-icons <dir>`: writes PNGs of the cup at several fill levels (both states)
/// onto a light background, for visually checking the glyph during development.
enum IconExport {
    @MainActor
    static func run(dir: String) -> Never {
        _ = NSApplication.shared // initialize AppKit so offscreen drawing has a context

        let fm = FileManager.default
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)

        let fills: [CGFloat] = [0, 0.25, 0.5, 0.75, 1.0]
        let px: CGFloat = 180
        for active in [false, true] {
            for fill in fills {
                let canvas = NSImage(size: NSSize(width: px, height: px))
                canvas.lockFocus()
                NSColor(white: 0.93, alpha: 1).setFill()
                NSBezierPath(rect: NSRect(x: 0, y: 0, width: px, height: px)).fill()
                let cup = CupIconRenderer.cupImage(fill: fill, active: active, size: px)
                cup.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
                canvas.unlockFocus()
                let name = "cup_\(active ? "active" : "inactive")_\(Int(fill * 100)).png"
                writePNG(canvas, to: "\(dir)/\(name)")
            }
        }
        print("Icons written to \(dir)")
        exit(0)
    }

    private static func writePNG(_ image: NSImage, to path: String) {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: URL(fileURLWithPath: path))
    }
}

#endif
