import Foundation

/// A simple countdown driven by a `Timer` on the **main run loop**, so its tick
/// callbacks (which redraw the status item) never touch AppKit off-thread.
final class SessionTimer {
    private var timer: Timer?
    private(set) var totalSeconds: TimeInterval = 0
    private(set) var remaining: TimeInterval = 0

    /// Called every second with (remaining, total).
    var onTick: ((TimeInterval, TimeInterval) -> Void)?
    /// Called once when the countdown reaches zero (after the final tick).
    var onFinish: (() -> Void)?

    var isRunning: Bool { timer != nil }

    func start(seconds: TimeInterval) {
        stop()
        totalSeconds = seconds
        remaining = seconds
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // .common keeps it firing while menus/popovers are tracking.
        RunLoop.main.add(t, forMode: .common)
        timer = t
        onTick?(remaining, totalSeconds)
    }

    private func tick() {
        remaining -= 1
        if remaining <= 0 {
            remaining = 0
            onTick?(remaining, totalSeconds)
            stop()
            onFinish?()
        } else {
            onTick?(remaining, totalSeconds)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        totalSeconds = 0
        remaining = 0
    }
}
