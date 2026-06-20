import Foundation

/// Thin UserDefaults-backed settings store. (Launch-at-login state is *not* stored
/// here — it's read directly from `SMAppService.mainApp.status`, the source of truth.)
enum Settings {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let keepDisplayAwake = "keepDisplayAwake"
        static let showCountdown = "showCountdown"
        static let autoSleepOnLowBattery = "autoSleepOnLowBattery"
        static let lowBatteryThreshold = "lowBatteryThreshold"
    }

    static var keepDisplayAwake: Bool {
        get { defaults.bool(forKey: Key.keepDisplayAwake) }
        set { defaults.set(newValue, forKey: Key.keepDisplayAwake) }
    }

    /// Defaults to `true` (showing the countdown is the more useful default).
    static var showCountdown: Bool {
        get {
            if defaults.object(forKey: Key.showCountdown) == nil { return true }
            return defaults.bool(forKey: Key.showCountdown)
        }
        set { defaults.set(newValue, forKey: Key.showCountdown) }
    }

    /// Battery safety net — defaults to `true` so a forgotten session can't drain the Mac.
    static var autoSleepOnLowBattery: Bool {
        get {
            if defaults.object(forKey: Key.autoSleepOnLowBattery) == nil { return true }
            return defaults.bool(forKey: Key.autoSleepOnLowBattery)
        }
        set { defaults.set(newValue, forKey: Key.autoSleepOnLowBattery) }
    }

    /// Percentage at/under which to let the Mac nap when on battery. Defaults to 20.
    static var lowBatteryThreshold: Int {
        get {
            let value = defaults.integer(forKey: Key.lowBatteryThreshold)
            return value == 0 ? 20 : value
        }
        set { defaults.set(newValue, forKey: Key.lowBatteryThreshold) }
    }
}
