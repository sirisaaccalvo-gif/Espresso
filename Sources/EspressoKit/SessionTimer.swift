import Foundation

/// A countdown pinned to a **wall-clock end date**, driven by a `Timer` on the
/// **main run loop** (its tick callbacks redraw the status item, so create and
/// drive this only from the main run loop — it is not thread-safe).
///
/// Remaining time is computed from the clock on every tick rather than counted
/// down, so a forced sleep (lid close — idle-sleep assertions don't prevent
/// that) can't stretch the session: `resync()` on wake ends any overdue
/// session immediately instead of resuming a frozen countdown.
public final class SessionTimer {
    private let now: () -> Date
    private var timer: Timer?
    private var endDate: Date?
    public private(set) var totalSeconds: TimeInterval = 0

    /// Called every second with (remaining, total). Remaining may be fractional.
    public var onTick: ((TimeInterval, TimeInterval) -> Void)?
    /// Called once when the countdown reaches zero (after the final tick).
    public var onFinish: (() -> Void)?

    public var isRunning: Bool { timer != nil }

    /// Seconds left; 0 when idle or overdue.
    public var remaining: TimeInterval {
        guard let endDate else { return 0 }
        return max(0, endDate.timeIntervalSince(now()))
    }

    /// - Parameter now: injectable clock so the countdown logic is unit-testable.
    public init(now: @escaping () -> Date = { Date() }) {
        self.now = now
    }

    public func start(seconds: TimeInterval) {
        stop()
        totalSeconds = seconds
        endDate = now().addingTimeInterval(seconds)
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.resync()
        }
        t.tolerance = 0.1 // slack is fine — remaining comes from the clock, not tick counts
        // .common keeps it firing while menus/popovers are tracking.
        RunLoop.main.add(t, forMode: .common)
        timer = t
        resync() // synchronous initial tick
    }

    /// Re-evaluate against the clock. The timer calls this every second; the app
    /// also calls it on system wake so an overdue session ends right away.
    public func resync() {
        guard endDate != nil else { return }
        let left = remaining
        if left <= 0 {
            let finish = onFinish
            onTick?(0, totalSeconds)
            stop()
            finish?()
        } else {
            onTick?(left, totalSeconds)
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        endDate = nil
        totalSeconds = 0
    }
}
