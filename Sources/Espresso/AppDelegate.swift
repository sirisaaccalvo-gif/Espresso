import AppKit
import EspressoKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    // Core
    private let controller = KeepAwakeController()
    private let timer = SessionTimer()
    private lazy var durationPopover: DurationPopoverController = {
        let p = DurationPopoverController()
        p.onStart = { [weak self] seconds in self?.activate(durationSeconds: seconds) }
        return p
    }()

    // UI
    private var statusItem: NSStatusItem!
    private var statusHeaderItem: NSMenuItem!
    private var batteryLidNoticeItem: NSMenuItem!
    private var keepAwakeItem: NSMenuItem!
    private var durationItems: [NSMenuItem] = []
    private var keepDisplayItem: NSMenuItem!
    private var showCountdownItem: NSMenuItem!
    private var batterySaverItem: NSMenuItem!
    private var batteryThresholdItems: [NSMenuItem] = []
    private var launchAtLoginItem: NSMenuItem!

    // State: nil currentDuration while active == indefinite.
    private var isActive = false
    private var currentDurationSeconds: TimeInterval?

    // Battery safety
    private let batteryThresholds = [10, 15, 20, 25, 30]
    private var batteryTimer: Timer?
    private let batteryPollInterval: TimeInterval = 30
    /// Set when a session ends for a notable reason (e.g. low battery); shown in the header.
    private var lastNapNote: String?

    /// Coffee-themed presets. (title, seconds) — seconds == 0 means indefinite, < 0 means "Custom…".
    /// Shorter pull = shorter session, naturally: ristretto → lungo → americano → bottomless.
    private let durationOptions: [(String, TimeInterval)] = [
        ("Ristretto · 15 min", 15 * 60),
        ("Espresso · 30 min", 30 * 60),
        ("Doppio · 1 hour", 60 * 60),
        ("Lungo · 2 hours", 2 * 60 * 60),
        ("Americano · 5 hours", 5 * 60 * 60),
        ("Bottomless · no limit", 0),
        ("Custom brew…", -1),
    ]

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageLeading

        timer.onTick = { [weak self] remaining, total in
            self?.handleTick(remaining: remaining, total: total)
        }
        timer.onFinish = { [weak self] in self?.deactivate() }

        buildMenu()
        refreshUI()

        #if ESPRESSO_DEVTOOLS
        // Debug-only hook: `--activate <seconds>` auto-starts a session on launch (0 = indefinite)
        // so the full activate→timer→assertion→auto-stop path can be exercised without the menu.
        let args = CommandLine.arguments
        if let idx = args.firstIndex(of: "--activate"), idx + 1 < args.count,
           let seconds = TimeInterval(args[idx + 1]) {
            activate(durationSeconds: seconds > 0 ? seconds : nil)
        }
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop() // never leave an orphaned assertion behind
    }

    // MARK: - Menu construction

    private func buildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        statusHeaderItem = NSMenuItem(title: "Sleeping normally", action: nil, keyEquivalent: "")
        statusHeaderItem.isEnabled = false
        menu.addItem(statusHeaderItem)

        // Persistent reminder (not the one-time setup alert) shown whenever a session is
        // active on battery — closing the lid still sleeps the Mac in that case, and a
        // dialog shown once at first-ever launch is too easy to forget by the time it matters.
        batteryLidNoticeItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        batteryLidNoticeItem.isEnabled = false
        batteryLidNoticeItem.isHidden = true
        menu.addItem(batteryLidNoticeItem)

        menu.addItem(.separator())

        keepAwakeItem = NSMenuItem(title: "Keep Awake",
                                   action: #selector(toggleKeepAwake),
                                   keyEquivalent: "")
        keepAwakeItem.target = self
        menu.addItem(keepAwakeItem)

        let durationParent = NSMenuItem(title: "Duration", action: nil, keyEquivalent: "")
        let durationMenu = NSMenu()
        for (index, option) in durationOptions.enumerated() {
            let item = NSMenuItem(title: option.0,
                                  action: #selector(selectDuration(_:)),
                                  keyEquivalent: "")
            item.target = self
            item.tag = index
            durationMenu.addItem(item)
            durationItems.append(item)
        }
        durationParent.submenu = durationMenu
        menu.addItem(durationParent)

        menu.addItem(.separator())

        keepDisplayItem = NSMenuItem(title: "Keep display awake too",
                                     action: #selector(toggleKeepDisplay),
                                     keyEquivalent: "")
        keepDisplayItem.target = self
        menu.addItem(keepDisplayItem)

        showCountdownItem = NSMenuItem(title: "Show countdown in menu bar",
                                       action: #selector(toggleShowCountdown),
                                       keyEquivalent: "")
        showCountdownItem.target = self
        menu.addItem(showCountdownItem)

        batterySaverItem = NSMenuItem(title: "Let it nap when battery is low",
                                      action: #selector(toggleBatterySaver),
                                      keyEquivalent: "")
        batterySaverItem.target = self
        menu.addItem(batterySaverItem)

        let thresholdParent = NSMenuItem(title: "Low-battery threshold", action: nil, keyEquivalent: "")
        let thresholdMenu = NSMenu()
        for (index, pct) in batteryThresholds.enumerated() {
            let item = NSMenuItem(title: "\(pct)%", action: #selector(selectThreshold(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            thresholdMenu.addItem(item)
            batteryThresholdItems.append(item)
        }
        thresholdParent.submenu = thresholdMenu
        menu.addItem(thresholdParent)

        menu.addItem(.separator())

        launchAtLoginItem = NSMenuItem(title: "Launch at login",
                                       action: #selector(toggleLaunchAtLogin),
                                       keyEquivalent: "")
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        let about = NSMenuItem(title: "About Espresso", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let quit = NSMenuItem(title: "Quit Espresso", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    // Refresh externally-owned state (login status) right before the menu opens.
    func menuWillOpen(_ menu: NSMenu) {
        refreshMenuChecks()
    }

    // MARK: - Actions

    @objc private func toggleKeepAwake() {
        if isActive { deactivate() } else { activate(durationSeconds: nil) }
    }

    @objc private func selectDuration(_ sender: NSMenuItem) {
        switch DurationLogic.parse(tag: sender.tag, secondsOptions: durationOptions.map { $0.1 }) {
        case .custom:
            // Let the menu finish closing, then show the popover.
            DispatchQueue.main.async { [weak self] in self?.showCustomDuration() }
        case .indefinite:
            activate(durationSeconds: nil)
        case .timed(let seconds):
            activate(durationSeconds: seconds)
        case .none:
            break
        }
    }

    @objc private func toggleKeepDisplay() {
        Settings.keepDisplayAwake.toggle()
        if isActive {
            // Add/remove only the display assertion — never drop the system one mid-session.
            controller.setDisplayAwake(Settings.keepDisplayAwake)
        }
        refreshMenuChecks()
    }

    @objc private func toggleShowCountdown() {
        Settings.showCountdown.toggle()
        refreshUI()
    }

    @objc private func toggleBatterySaver() {
        Settings.autoSleepOnLowBattery.toggle()
        if isActive {
            if Settings.autoSleepOnLowBattery {
                startBatteryTimer()  // begin polling and apply immediately
                checkBattery()
            } else {
                stopBatteryTimer()   // don't keep polling when disabled
            }
        }
        refreshMenuChecks()
    }

    @objc private func selectThreshold(_ sender: NSMenuItem) {
        Settings.lowBatteryThreshold = batteryThresholds[sender.tag]
        if isActive, Settings.autoSleepOnLowBattery { checkBattery() } // timer already running
        refreshMenuChecks()
    }

    @objc private func toggleLaunchAtLogin() {
        let ok = LaunchAtLogin.set(!LaunchAtLogin.isEnabled)
        if !ok {
            // SMAppService can be refused for an unsigned/ad-hoc build — tell the user
            // rather than silently leaving the checkbox unchanged.
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "Couldn’t update Launch at Login"
            alert.informativeText = "macOS blocked the change. This works once Espresso is a signed build (Developer ID or App Store). For now you can add it manually in System Settings ▸ General ▸ Login Items."
            alert.runModal()
        }
        refreshMenuChecks()
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Espresso ☕"
        alert.informativeText = "Keeps your Mac wide awake — one shot at a time.\n\nPick a brew (Ristretto to Bottomless), and the little cup sips it down as the timer runs. No Dock clutter; it lives in your menu bar.\n\nVersion 1.0 · by Isaac Calvo · isaaccalvo.com"
        if let data = MascotRenderer.png(pixels: 160, awake: true, background: true),
           let icon = NSImage(data: data) {
            alert.icon = icon
        }
        alert.addButton(withTitle: "Nice ☕")
        alert.addButton(withTitle: "Website")
        if alert.runModal() == .alertSecondButtonReturn,
           let url = URL(string: "https://isaaccalvo.com") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func showCustomDuration() {
        guard let button = statusItem.button else { return }
        durationPopover.show(relativeTo: button)
    }

    // MARK: - State transitions

    private func activate(durationSeconds: TimeInterval?) {
        lastNapNote = nil
        isActive = true
        currentDurationSeconds = durationSeconds
        controller.start(keepDisplayAwake: Settings.keepDisplayAwake)
        maybeShowLidSetupNotice()
        if let seconds = durationSeconds {
            timer.start(seconds: seconds)
        } else {
            timer.stop()
        }
        if Settings.autoSleepOnLowBattery {
            startBatteryTimer()
            checkBattery() // nap right away if we're already at/under the threshold on battery
        } else {
            stopBatteryTimer()
        }
        refreshUI()
    }

    /// One-time, laptop-only nudge: closing the lid only keeps the Mac awake once the user enables
    /// macOS's "prevent sleep when the display is off" setting (we can't toggle it without root).
    /// Shown the first time a session starts; never nags again.
    private func maybeShowLidSetupNotice() {
        guard !Settings.didShowLidSetup else { return }
        // Desktops have no lid; only laptops report a battery percentage.
        guard BatteryGuard.currentPowerState().percent != nil else { return }
        Settings.didShowLidSetup = true

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Keep awake with the lid closed"
        alert.informativeText = "Espresso can keep your Mac running with the lid closed and the screen off — while it’s plugged in.\n\nTurn on “Prevent automatic sleeping when the display is off” in System Settings ▸ Displays to enable it. (On battery, closing the lid still sleeps to save power.)"
        alert.addButton(withTitle: "Open Display Settings")
        alert.addButton(withTitle: "OK")
        if alert.runModal() == .alertFirstButtonReturn {
            // Try the modern pane id first, then the legacy one.
            for string in ["x-apple.systempreferences:com.apple.Displays-Settings.extension",
                           "x-apple.systempreferences:com.apple.preference.displays"] {
                if let url = URL(string: string), NSWorkspace.shared.open(url) { break }
            }
        }
    }

    private func deactivate(napNote: String? = nil) {
        isActive = false
        currentDurationSeconds = nil
        timer.stop()
        stopBatteryTimer()
        controller.stop()
        lastNapNote = napNote
        refreshUI()
    }

    // MARK: - Battery safety

    private func startBatteryTimer() {
        stopBatteryTimer()
        let t = Timer(timeInterval: batteryPollInterval, repeats: true) { [weak self] _ in
            self?.checkBattery()
        }
        RunLoop.main.add(t, forMode: .common)
        batteryTimer = t
    }

    private func stopBatteryTimer() {
        batteryTimer?.invalidate()
        batteryTimer = nil
    }

    private func checkBattery() {
        guard isActive, Settings.autoSleepOnLowBattery else { return }
        let decision = BatteryOrchestrator.decideNap(
            enabled: Settings.autoSleepOnLowBattery,
            power: BatteryGuard.currentPowerState(),
            threshold: Settings.lowBatteryThreshold)
        if decision.shouldEnd {
            deactivate(napNote: decision.reason)
        }
    }

    /// Refreshed every time the menu opens (see `menuWillOpen`) and on every activate/deactivate/
    /// toggle, so it reflects live power state rather than a snapshot from when the session started.
    private func refreshBatteryLidNotice() {
        let show = BatteryGuard.shouldShowLidNotice(isActive: isActive, power: BatteryGuard.currentPowerState())
        batteryLidNoticeItem?.isHidden = !show
        batteryLidNoticeItem?.title = show ? "Lid close still sleeps the Mac on battery ⚠️" : ""
    }

    // MARK: - UI updates

    private func handleTick(remaining: TimeInterval, total: TimeInterval) {
        let fraction = total > 0 ? CGFloat(remaining / total) : 1.0
        updateIcon(fill: fraction, countdown: remaining)
        statusHeaderItem.title = "Wide awake — \(TimeFormatting.clock(remaining)) left"
    }

    private func refreshUI() {
        if isActive {
            if let total = currentDurationSeconds, total > 0 {
                let fraction = CGFloat(timer.remaining / total)
                updateIcon(fill: fraction, countdown: timer.remaining)
                statusHeaderItem.title = "Wide awake — \(TimeFormatting.clock(timer.remaining)) left"
            } else {
                updateIcon(fill: 1.0, countdown: nil)
                statusHeaderItem.title = "Wide awake — no limit ☕"
            }
        } else {
            updateIcon(fill: 0, countdown: nil)
            statusHeaderItem.title = lastNapNote ?? "Letting it nap 😴"
        }
        refreshMenuChecks()
    }

    private func updateIcon(fill: CGFloat, countdown: TimeInterval?) {
        guard let button = statusItem.button else { return }
        button.image = CupIconRenderer.cupImage(fill: fill, active: isActive)

        if isActive, Settings.showCountdown, let countdown = countdown {
            let font = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .regular)
            button.attributedTitle = NSAttributedString(
                string: " " + TimeFormatting.abbreviated(countdown),
                attributes: [.font: font])
            button.imagePosition = .imageLeading
        } else {
            button.attributedTitle = NSAttributedString(string: "")
            button.imagePosition = .imageOnly
        }
    }

    private func refreshMenuChecks() {
        refreshBatteryLidNotice()

        keepAwakeItem?.state = isActive ? .on : .off

        let activeSeconds = currentDurationSeconds
        for (index, item) in durationItems.enumerated() {
            let seconds = durationOptions[index].1
            var on = false
            if isActive {
                if seconds == 0 {
                    on = (activeSeconds == nil)
                } else if seconds > 0 {
                    on = (activeSeconds == seconds)
                }
            }
            item.state = on ? .on : .off
        }

        keepDisplayItem?.state = Settings.keepDisplayAwake ? .on : .off
        showCountdownItem?.state = Settings.showCountdown ? .on : .off
        batterySaverItem?.state = Settings.autoSleepOnLowBattery ? .on : .off
        for (index, item) in batteryThresholdItems.enumerated() {
            item.state = (batteryThresholds[index] == Settings.lowBatteryThreshold) ? .on : .off
        }
        launchAtLoginItem?.state = LaunchAtLogin.isEnabled ? .on : .off
    }
}
