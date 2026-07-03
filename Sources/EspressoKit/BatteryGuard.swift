import Foundation
import IOKit.ps

/// A snapshot of the Mac's power source.
public struct PowerState: Equatable {
    public let onBattery: Bool
    /// Current charge 0–100, or nil if unknown / no battery (desktops).
    public let percent: Int?

    public init(onBattery: Bool, percent: Int?) {
        self.onBattery = onBattery
        self.percent = percent
    }
}

/// Battery safety: optionally let the Mac nap when it's on battery and the charge
/// drops to/under a threshold, so a forgotten keep-awake session can't drain it flat.
public enum BatteryGuard {

    /// Pure decision (unit-tested). Returns true when keep-awake should auto-disable.
    public static func shouldLetNap(enabled: Bool, onBattery: Bool, percent: Int?, threshold: Int) -> Bool {
        guard enabled, onBattery, let percent else { return false }
        return percent <= threshold
    }

    /// Pure decision (unit-tested): whether to show the persistent menu reminder that
    /// closing the lid still sleeps the Mac while on battery. True only for an active
    /// session, currently on battery, on a machine that has a battery (laptops only —
    /// desktops report no percent).
    public static func shouldShowLidNotice(isActive: Bool, power: PowerState) -> Bool {
        isActive && power.onBattery && power.percent != nil
    }

    /// Live power-source snapshot via IOKit. Desktops (no battery) report onBattery=false.
    public static func currentPowerState() -> PowerState {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              !sources.isEmpty else {
            return PowerState(onBattery: false, percent: nil)
        }
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() as? [String: Any] else { continue }
            let state = desc[kIOPSPowerSourceStateKey as String] as? String
            let onBattery = (state == (kIOPSBatteryPowerValue as String))
            var percent: Int?
            if let current = desc[kIOPSCurrentCapacityKey as String] as? Int,
               let maximum = desc[kIOPSMaxCapacityKey as String] as? Int, maximum > 0 {
                percent = Int((Double(current) / Double(maximum) * 100.0).rounded())
            }
            return PowerState(onBattery: onBattery, percent: percent)
        }
        return PowerState(onBattery: false, percent: nil)
    }
}
