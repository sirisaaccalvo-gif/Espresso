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

    /// Live power-source snapshot via IOKit. Desktops (no battery) report onBattery=false.
    public static func currentPowerState() -> PowerState {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else {
            return PowerState(onBattery: false, percent: nil)
        }
        let descriptions = sources.compactMap {
            IOPSGetPowerSourceDescription(snapshot, $0)?.takeUnretainedValue() as? [String: Any]
        }
        return powerState(fromDescriptions: descriptions)
    }

    /// Pure parsing/selection (unit-tested). Reads ONLY the internal battery — this
    /// feature protects the Mac's own battery, not a UPS (which can appear first in,
    /// or be the sole entry of, the source list); with no internal battery (desktops)
    /// it reports onBattery=false so the guard never fires.
    public static func powerState(fromDescriptions descriptions: [[String: Any]]) -> PowerState {
        let internalBattery = descriptions.first {
            ($0[kIOPSTypeKey as String] as? String) == (kIOPSInternalBatteryType as String)
        }
        guard let desc = internalBattery else {
            return PowerState(onBattery: false, percent: nil)
        }
        let state = desc[kIOPSPowerSourceStateKey as String] as? String
        let onBattery = (state == (kIOPSBatteryPowerValue as String))
        var percent: Int?
        if let current = desc[kIOPSCurrentCapacityKey as String] as? Int,
           let maximum = desc[kIOPSMaxCapacityKey as String] as? Int, maximum > 0 {
            percent = min(100, max(0, Int((Double(current) / Double(maximum) * 100.0).rounded())))
        }
        return PowerState(onBattery: onBattery, percent: percent)
    }
}
