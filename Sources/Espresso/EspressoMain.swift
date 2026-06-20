import AppKit

@main
enum EspressoMain {
    // Held strongly for the process lifetime (NSApplication.delegate is weak).
    @MainActor static var delegate: AppDelegate?

    @MainActor
    static func main() {
        let arguments = CommandLine.arguments

        // Hidden CLI modes for development/verification — handled before the GUI starts.
        if arguments.contains("--selftest") {
            SelfTest.run()
        }
        if let idx = arguments.firstIndex(of: "--render-icons"), idx + 1 < arguments.count {
            IconExport.run(dir: arguments[idx + 1])
        }
        if let idx = arguments.firstIndex(of: "--make-icon"), idx + 1 < arguments.count {
            AppIconExport.run(dir: arguments[idx + 1])
        }
        if let idx = arguments.firstIndex(of: "--render-popover"), idx + 1 < arguments.count {
            _ = NSApplication.shared
            DurationPopoverController().renderPreview(to: arguments[idx + 1])
            exit(0)
        }
        if let idx = arguments.firstIndex(of: "--make-screenshots"), idx + 1 < arguments.count {
            ScreenshotRenderer.make(dir: arguments[idx + 1])
        }

        // Normal launch: menu-bar-only AppKit app.
        let app = NSApplication.shared
        let appDelegate = AppDelegate()
        delegate = appDelegate
        app.delegate = appDelegate
        app.setActivationPolicy(.accessory) // no Dock icon; belt-and-suspenders with LSUIElement
        app.run()
    }
}
