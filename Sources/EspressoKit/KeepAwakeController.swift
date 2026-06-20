import Foundation
import IOKit
import IOKit.pwr_mgt

/// Wraps IOKit power assertions — the same mechanism `caffeinate` uses.
///
/// `PreventUserIdleSystemSleep` keeps the system awake while letting the display
/// sleep (`caffeinate -i`); `PreventUserIdleDisplaySleep` keeps the display — and
/// therefore the system — awake (`caffeinate -d`). Always pair create with release.
public final class KeepAwakeController {
    private var systemAssertion: IOPMAssertionID = 0
    private var displayAssertion: IOPMAssertionID = 0
    public private(set) var isActive = false

    public init() {}

    /// Start preventing sleep. Idempotent — re-starting releases and recreates assertions.
    public func start(keepDisplayAwake: Bool, reason: String = "Espresso is keeping your Mac awake") {
        stop()
        systemAssertion = createAssertion(kIOPMAssertionTypePreventUserIdleSystemSleep, reason)
        if keepDisplayAwake {
            displayAssertion = createAssertion(kIOPMAssertionTypePreventUserIdleDisplaySleep, reason)
        }
        isActive = true
    }

    /// Add or remove ONLY the display assertion, leaving the system assertion untouched.
    /// Used for a mid-session "keep display awake" toggle so we never momentarily drop the
    /// core keep-the-system-awake guarantee (the fix for the stop-then-start window).
    public func setDisplayAwake(_ on: Bool, reason: String = "Espresso is keeping your Mac awake") {
        guard isActive else { return }
        if on {
            if displayAssertion == 0 {
                displayAssertion = createAssertion(kIOPMAssertionTypePreventUserIdleDisplaySleep, reason)
            }
        } else if displayAssertion != 0 {
            IOPMAssertionRelease(displayAssertion)
            displayAssertion = 0
        }
    }

    /// Release all assertions. Safe to call repeatedly.
    public func stop() {
        if systemAssertion != 0 {
            IOPMAssertionRelease(systemAssertion)
            systemAssertion = 0
        }
        if displayAssertion != 0 {
            IOPMAssertionRelease(displayAssertion)
            displayAssertion = 0
        }
        isActive = false
    }

    private func createAssertion(_ type: String, _ reason: String) -> IOPMAssertionID {
        var id: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(
            type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), reason as CFString, &id)
        if result != kIOReturnSuccess {
            NSLog("Espresso: failed to create power assertion \(type): \(result)")
            return 0
        }
        return id
    }

    deinit { stop() }
}
