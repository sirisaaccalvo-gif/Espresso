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
}
