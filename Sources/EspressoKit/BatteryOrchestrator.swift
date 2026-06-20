import Foundation

/// The outcome of a battery-safety check: whether to end the session, and the note to show.
public struct NapDecision: Equatable {
    public let shouldEnd: Bool
    public let reason: String?
    public init(shouldEnd: Bool, reason: String?) {
        self.shouldEnd = shouldEnd
        self.reason = reason
    }
}

/// Pure orchestration of the low-battery safety decision (extracted from AppDelegate so it
/// — including the user-facing message — is unit-testable).
public enum BatteryOrchestrator {
    public static func decideNap(enabled: Bool, power: PowerState, threshold: Int) -> NapDecision {
        guard BatteryGuard.shouldLetNap(enabled: enabled, onBattery: power.onBattery,
                                        percent: power.percent, threshold: threshold) else {
            return NapDecision(shouldEnd: false, reason: nil)
        }
        let pct = power.percent ?? threshold
        return NapDecision(shouldEnd: true, reason: "Napped to save battery (\(pct)%) 🪫")
    }
}
