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

    /// True only while a system assertion is actually held — computed from the
    /// assertion ID so the UI can never claim "awake" when creation failed.
    public var isActive: Bool { systemAssertion != 0 }

    public init() {}

    /// Start preventing sleep. Idempotent — re-starting swaps in fresh assertions,
    /// creating the new ones **before** releasing the old so a mid-session restart
    /// never momentarily drops sleep protection. Returns false when no system
    /// assertion could be created or kept — i.e. the Mac is NOT being kept awake.
    @discardableResult
    public func start(keepDisplayAwake: Bool, reason: String = "Espresso is keeping your Mac awake") -> Bool {
        let oldSystem = systemAssertion
        let oldDisplay = displayAssertion
        let newSystem = createAssertion(kIOPMAssertionTypePreventUserIdleSystemSleep, reason)
        if newSystem == 0 {
            // Creation failed — keep whatever was already held and report honestly.
            return systemAssertion != 0
        }
        systemAssertion = newSystem
        displayAssertion = keepDisplayAwake
            ? createAssertion(kIOPMAssertionTypePreventUserIdleDisplaySleep, reason) : 0
        if oldSystem != 0 { IOPMAssertionRelease(oldSystem) }
        if oldDisplay != 0 { IOPMAssertionRelease(oldDisplay) }
        return true
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
