import Foundation

/// Pure time-formatting helpers (in EspressoKit so they're testable without the UI/app).
public enum TimeFormatting {
    /// Countdown convention: fractional remaining rounds UP, so a fresh 30-minute
    /// session reads "30m" (not "29m" a split second in) and the display reaches
    /// zero only when the session actually has.
    private static func wholeSeconds(_ seconds: TimeInterval) -> Int {
        max(0, Int(seconds.rounded(.up)))
    }

    /// Compact menu-bar label: "5h", "1h 1m", "42m", "30s".
    public static func abbreviated(_ seconds: TimeInterval) -> String {
        let total = wholeSeconds(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
        if m > 0 { return "\(m)m" }
        return "\(s)s"
    }

    /// Verbose status-line clock: "1:02:05" or "42:15".
    public static func clock(_ seconds: TimeInterval) -> String {
        let total = wholeSeconds(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
