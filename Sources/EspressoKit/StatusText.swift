import Foundation

/// Pure composition of the user-facing status strings (menu header + status-item
/// tooltip), extracted so the exact wording is unit-testable and written once.
/// `remaining == nil` while active means an indefinite session.
public enum StatusText {
    /// The disabled header line at the top of the menu.
    public static func header(isActive: Bool, remaining: TimeInterval?, napNote: String?) -> String {
        guard isActive else { return napNote ?? "Letting it nap 😴" }
        if let remaining {
            return "Wide awake — \(TimeFormatting.clock(remaining)) left"
        }
        return "Wide awake — no limit ☕"
    }

    /// Status-item tooltip; doubles as the accessibility label. While idle, a nap
    /// note (e.g. "Brew finished ☕") explains how the last session ended — hovering
    /// answers "why did it stop?" without opening the menu.
    public static func toolTip(isActive: Bool, remaining: TimeInterval?, napNote: String? = nil) -> String {
        guard isActive else { return "Espresso — " + (napNote ?? "letting your Mac nap") }
        if let remaining {
            return "Espresso — keeping your Mac awake, \(TimeFormatting.abbreviated(remaining)) left"
        }
        return "Espresso — keeping your Mac awake, no limit"
    }
}
