import Foundation

/// What a duration-menu item means.
public enum DurationSelection: Equatable {
    case custom
    case indefinite
    case timed(TimeInterval)
}

/// Pure mapping of a duration-menu tag to a selection (extracted from AppDelegate so the
/// <0 = custom / 0 = indefinite / >0 = timed convention is unit-testable and not duplicated).
public enum DurationLogic {
    public static func parse(tag: Int, secondsOptions: [TimeInterval]) -> DurationSelection? {
        guard secondsOptions.indices.contains(tag) else { return nil }
        let seconds = secondsOptions[tag]
        if seconds < 0 { return .custom }
        if seconds == 0 { return .indefinite }
        return .timed(seconds)
    }

    /// Checkmark states for the duration menu, one per option. While active,
    /// `activeSeconds == nil` means indefinite (checks the 0 option); a timed
    /// session checks its matching preset, or the custom option (< 0) when it
    /// matches no preset — a custom duration equal to a preset lights the preset.
    public static func checkStates(isActive: Bool, activeSeconds: TimeInterval?,
                                   secondsOptions: [TimeInterval]) -> [Bool] {
        guard isActive else { return secondsOptions.map { _ in false } }
        let matchesPreset = activeSeconds.map { active in
            secondsOptions.contains { $0 > 0 && $0 == active }
        } ?? false
        return secondsOptions.map { seconds in
            if seconds == 0 { return activeSeconds == nil }
            if seconds > 0 { return activeSeconds == seconds }
            return activeSeconds != nil && !matchesPreset
        }
    }
}
