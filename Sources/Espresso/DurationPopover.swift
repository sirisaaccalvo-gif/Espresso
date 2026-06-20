import AppKit

/// A small popover anchored to the status item for entering a custom session length —
/// the native menu-bar pattern. Uses a single HH:MM time dial (one control for hours +
/// minutes) and full Auto Layout so the Brew button can never be clipped.
@MainActor
final class DurationPopoverController: NSObject {
    private let popover = NSPopover()
    private let picker = NSDatePicker()

    /// Called with the chosen duration in seconds when the user taps Brew.
    var onStart: ((TimeInterval) -> Void)?

    override init() {
        super.init()
        popover.behavior = .transient
        popover.contentViewController = makeViewController()
    }

    var isShown: Bool { popover.isShown }

    func show(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        if let view = popover.contentViewController?.view {
            view.layoutSubtreeIfNeeded()
            popover.contentSize = view.fittingSize // size to content → nothing clips
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func makeViewController() -> NSViewController {
        let vc = NSViewController()
        let root = NSView()

        let title = NSTextField(labelWithString: "Brew for how long?")
        title.font = .boldSystemFont(ofSize: 13)

        // Single HH:MM dial: one field + one stepper for both hours and minutes.
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = .hourMinute
        picker.datePickerMode = .single
        picker.font = .monospacedDigitSystemFont(ofSize: 24, weight: .medium)
        picker.locale = Locale(identifier: "en_GB") // 24h HH:MM, no AM/PM for a duration
        picker.calendar = Calendar(identifier: .gregorian)
        picker.dateValue = referenceDate(hours: 0, minutes: 30) // default 0:30

        let hint = NSTextField(labelWithString: "hours : minutes")
        hint.font = .systemFont(ofSize: 10)
        hint.textColor = .secondaryLabelColor

        let brew = NSButton(title: "Brew ☕", target: self, action: #selector(startTapped))
        brew.bezelStyle = .rounded
        brew.controlSize = .large
        brew.keyEquivalent = "\r"

        let stack = NSStackView(views: [title, picker, hint, brew])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        root.addSubview(stack)
        NSLayoutConstraint.activate([
            // Pin on ALL FOUR edges so the root height is driven by content (no clipping).
            stack.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),
            // Brew button spans the full width.
            brew.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            brew.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
            root.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
        ])
        vc.view = root
        return vc
    }

    private func referenceDate(hours: Int, minutes: Int) -> Date {
        var comps = DateComponents()
        comps.year = 2001; comps.month = 1; comps.day = 1
        comps.hour = hours; comps.minute = minutes
        return Calendar(identifier: .gregorian).date(from: comps) ?? Date(timeIntervalSinceReferenceDate: 0)
    }

    /// Dev helper: render the popover content offscreen to a PNG so layout can be checked
    /// without driving the menu by hand. (`--render-popover <path>`.)
    func renderPreview(to path: String) {
        guard let view = popover.contentViewController?.view else { return }
        view.layoutSubtreeIfNeeded()
        view.frame = NSRect(origin: .zero, size: view.fittingSize)
        let window = NSWindow(contentRect: view.frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.contentView = view
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        view.layoutSubtreeIfNeeded()
        guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: path))
        }
    }

    @objc private func startTapped() {
        let comps = Calendar(identifier: .gregorian).dateComponents([.hour, .minute], from: picker.dateValue)
        let seconds = TimeInterval((comps.hour ?? 0) * 3600 + (comps.minute ?? 0) * 60)
        popover.performClose(nil)
        if seconds > 0 {
            onStart?(seconds)
        }
    }
}
