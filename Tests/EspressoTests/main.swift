import Foundation
import IOKit.ps
import EspressoKit

// Dependency-free test runner (XCTest/Testing aren't available with Command Line Tools only).
// Run with:  swift run EspressoTests   — exits non-zero if any check fails.

var failures = 0
var groups = 0

func group(_ name: String) { groups += 1; print("\n• \(name)") }
func check(_ condition: Bool, _ message: String) {
    if condition { print("  ✓ \(message)") }
    else { print("  ✗ FAIL — \(message)"); failures += 1 }
}
func eq<T: Equatable>(_ got: T, _ want: T, _ message: String) {
    check(got == want, "\(message)  (got \(got), want \(want))")
}

group("TimeFormatting.abbreviated")
eq(TimeFormatting.abbreviated(0), "0s", "0 → 0s")
eq(TimeFormatting.abbreviated(45), "45s", "45 → 45s")
eq(TimeFormatting.abbreviated(60), "1m", "60 → 1m")
eq(TimeFormatting.abbreviated(905), "15m", "905 → 15m")
eq(TimeFormatting.abbreviated(3600), "1h", "3600 → 1h")
eq(TimeFormatting.abbreviated(3660), "1h 1m", "3660 → 1h 1m")
eq(TimeFormatting.abbreviated(7200), "2h", "7200 → 2h")
eq(TimeFormatting.abbreviated(18000), "5h", "18000 → 5h")
eq(TimeFormatting.abbreviated(-5), "0s", "negative clamps → 0s")

group("TimeFormatting.clock")
eq(TimeFormatting.clock(0), "0:00", "0 → 0:00")
eq(TimeFormatting.clock(75), "1:15", "75 → 1:15")
eq(TimeFormatting.clock(615), "10:15", "615 → 10:15")
eq(TimeFormatting.clock(3661), "1:01:01", "3661 → 1:01:01")
eq(TimeFormatting.clock(7325), "2:02:05", "7325 → 2:02:05")

group("BatteryGuard.shouldLetNap")
check(BatteryGuard.shouldLetNap(enabled: false, onBattery: true, percent: 5, threshold: 20) == false, "disabled never naps")
check(BatteryGuard.shouldLetNap(enabled: true, onBattery: false, percent: 5, threshold: 20) == false, "on AC never naps")
check(BatteryGuard.shouldLetNap(enabled: true, onBattery: true, percent: nil, threshold: 20) == false, "unknown % never naps")
check(BatteryGuard.shouldLetNap(enabled: true, onBattery: true, percent: 20, threshold: 20) == true, "naps at threshold")
check(BatteryGuard.shouldLetNap(enabled: true, onBattery: true, percent: 10, threshold: 20) == true, "naps below threshold")
check(BatteryGuard.shouldLetNap(enabled: true, onBattery: true, percent: 21, threshold: 20) == false, "stays awake just above")
check(BatteryGuard.shouldLetNap(enabled: true, onBattery: true, percent: 100, threshold: 20) == false, "stays awake at full")

group("BatteryGuard.powerState(fromDescriptions:)")
do {
    let typeKey = kIOPSTypeKey as String
    let stateKey = kIOPSPowerSourceStateKey as String
    let currentKey = kIOPSCurrentCapacityKey as String
    let maximumKey = kIOPSMaxCapacityKey as String
    let internalType = kIOPSInternalBatteryType as String
    let battPower = kIOPSBatteryPowerValue as String
    let acPower = kIOPSACPowerValue as String

    check(BatteryGuard.powerState(fromDescriptions: []) == PowerState(onBattery: false, percent: nil),
          "no sources (or none parsable) → on AC, unknown %")

    let onBattery: [String: Any] = [typeKey: internalType, stateKey: battPower, currentKey: 47, maximumKey: 93]
    let parsed = BatteryGuard.powerState(fromDescriptions: [onBattery])
    check(parsed.onBattery == true, "internal battery discharging → on battery")
    eq(parsed.percent ?? -1, 51, "percent rounds from raw capacities (47/93 → 51)")

    let charging: [String: Any] = [typeKey: internalType, stateKey: acPower, currentKey: 90, maximumKey: 100]
    check(BatteryGuard.powerState(fromDescriptions: [charging]) == PowerState(onBattery: false, percent: 90),
          "internal battery on AC → not on battery")

    let ups: [String: Any] = [typeKey: kIOPSUPSType as String, stateKey: battPower, currentKey: 10, maximumKey: 100]
    check(BatteryGuard.powerState(fromDescriptions: [ups, charging]) == PowerState(onBattery: false, percent: 90),
          "internal battery wins over a UPS listed first")

    let noCapacity: [String: Any] = [typeKey: internalType, stateKey: battPower]
    check(BatteryGuard.powerState(fromDescriptions: [noCapacity]) == PowerState(onBattery: true, percent: nil),
          "missing capacity keys → nil percent")
}

group("BatteryGuard.currentPowerState (live IOKit)")
let power = BatteryGuard.currentPowerState()
if let p = power.percent { check((0...100).contains(p), "reported percent \(p) is 0–100") }
else { check(true, "no battery percent (desktop) — ok") }

group("BatteryOrchestrator.decideNap")
do {
    let off = BatteryOrchestrator.decideNap(enabled: false, power: PowerState(onBattery: true, percent: 5), threshold: 20)
    check(off.shouldEnd == false, "disabled → no nap")
    check(off.reason == nil, "disabled → no reason")

    let ac = BatteryOrchestrator.decideNap(enabled: true, power: PowerState(onBattery: false, percent: 5), threshold: 20)
    check(ac.shouldEnd == false, "on AC → no nap")

    let low = BatteryOrchestrator.decideNap(enabled: true, power: PowerState(onBattery: true, percent: 18), threshold: 20)
    check(low.shouldEnd == true, "battery 18% ≤ 20 → nap")
    check(low.reason == "Napped to save battery (18%) 🪫", "reason includes the live percent")

    let high = BatteryOrchestrator.decideNap(enabled: true, power: PowerState(onBattery: true, percent: 80), threshold: 20)
    check(high.shouldEnd == false, "battery 80% → no nap")

    let unknown = BatteryOrchestrator.decideNap(enabled: true, power: PowerState(onBattery: true, percent: nil), threshold: 20)
    check(unknown.shouldEnd == false, "unknown % → no nap")
}

group("DurationLogic.parse")
do {
    // Mirrors AppDelegate's durationOptions seconds: presets, 0 = indefinite, -1 = custom.
    let opts: [TimeInterval] = [900, 1800, 3600, 7200, 18000, 0, -1]
    check(DurationLogic.parse(tag: 0, secondsOptions: opts) == .timed(900), "tag 0 → 15 min")
    check(DurationLogic.parse(tag: 4, secondsOptions: opts) == .timed(18000), "tag 4 → 5 hours")
    check(DurationLogic.parse(tag: 5, secondsOptions: opts) == .indefinite, "tag 5 → indefinite")
    check(DurationLogic.parse(tag: 6, secondsOptions: opts) == .custom, "tag 6 → custom")
    check(DurationLogic.parse(tag: 99, secondsOptions: opts) == nil, "out-of-range → nil")
    check(DurationLogic.parse(tag: -1, secondsOptions: opts) == nil, "negative tag → nil")
}

group("StatusText")
do {
    eq(StatusText.header(isActive: true, remaining: 3661, napNote: nil),
       "Wide awake — 1:01:01 left", "active timed header")
    eq(StatusText.header(isActive: true, remaining: nil, napNote: nil),
       "Wide awake — no limit ☕", "active indefinite header")
    eq(StatusText.header(isActive: false, remaining: nil, napNote: nil),
       "Letting it nap 😴", "idle header")
    eq(StatusText.header(isActive: false, remaining: nil, napNote: "Napped to save battery (18%) 🪫"),
       "Napped to save battery (18%) 🪫", "idle header surfaces the nap note")

    eq(StatusText.toolTip(isActive: true, remaining: 2520),
       "Espresso — keeping your Mac awake, 42m left", "active timed tooltip")
    eq(StatusText.toolTip(isActive: true, remaining: nil),
       "Espresso — keeping your Mac awake, no limit", "active indefinite tooltip")
    eq(StatusText.toolTip(isActive: false, remaining: nil),
       "Espresso — letting your Mac nap", "idle tooltip")
}

group("DurationLogic.checkStates")
do {
    // Mirrors AppDelegate's durationOptions seconds: presets, 0 = indefinite, -1 = custom.
    let opts: [TimeInterval] = [900, 1800, 3600, 7200, 18000, 0, -1]
    eq(DurationLogic.checkStates(isActive: false, activeSeconds: nil, secondsOptions: opts),
       [false, false, false, false, false, false, false], "inactive → nothing checked")
    eq(DurationLogic.checkStates(isActive: true, activeSeconds: 1800, secondsOptions: opts),
       [false, true, false, false, false, false, false], "preset session checks its preset")
    eq(DurationLogic.checkStates(isActive: true, activeSeconds: nil, secondsOptions: opts),
       [false, false, false, false, false, true, false], "indefinite session checks the no-limit option")
    eq(DurationLogic.checkStates(isActive: true, activeSeconds: 2700, secondsOptions: opts),
       [false, false, false, false, false, false, true], "custom 45m session checks Custom brew")
    eq(DurationLogic.checkStates(isActive: true, activeSeconds: 1800, secondsOptions: opts)[6],
       false, "a custom duration equal to a preset lights the preset, not Custom")
}

group("SessionTimer (wall-clock, injected clock)")
do {
    // No run loop spins in this runner, so the internal Timer never fires;
    // every evaluation is driven explicitly through resync().
    var fakeNow = Date(timeIntervalSinceReferenceDate: 1_000)
    let st = SessionTimer(now: { fakeNow })
    var ticks: [(remaining: TimeInterval, total: TimeInterval)] = []
    var finishes = 0
    st.onTick = { ticks.append(($0, $1)) }
    st.onFinish = { finishes += 1 }

    eq(st.remaining, 0, "remaining is 0 before start")
    check(st.isRunning == false, "not running before start")

    st.start(seconds: 60)
    check(st.isRunning, "running after start")
    eq(ticks.count, 1, "start fires a synchronous initial tick")
    eq(ticks.last?.remaining ?? -1, 60, "initial tick reports full remaining")
    eq(ticks.last?.total ?? -1, 60, "initial tick reports the total")

    fakeNow = fakeNow.addingTimeInterval(10)
    st.resync()
    eq(st.remaining, 50, "remaining tracks the wall clock")
    eq(ticks.last?.remaining ?? -1, 50, "tick reports wall-clock remaining")
    eq(finishes, 0, "no finish mid-session")

    fakeNow = fakeNow.addingTimeInterval(3_600) // simulated sleep far past the end
    st.resync()
    eq(finishes, 1, "overshooting the end finishes exactly once")
    eq(ticks.last?.remaining ?? -1, 0, "final tick reports 0 remaining")
    check(st.isRunning == false, "stopped after finish")
    eq(st.remaining, 0, "remaining is 0 after finish")
    st.resync()
    eq(finishes, 1, "resync after finish is a no-op")

    st.start(seconds: 30)
    fakeNow = fakeNow.addingTimeInterval(5)
    st.stop()
    fakeNow = fakeNow.addingTimeInterval(100)
    st.resync()
    eq(finishes, 1, "stop() midway prevents the finish callback")

    st.start(seconds: 45)
    check(st.isRunning, "restart after finish works")
    eq(st.remaining, 45, "restart resets remaining")
    st.stop()
}

group("KeepAwakeController (live IOKit assertions)")
let c = KeepAwakeController()
check(c.isActive == false, "starts inactive")
check(c.start(keepDisplayAwake: false) == true, "start succeeds and says so")
check(c.isActive == true, "active after start")
c.setDisplayAwake(true)
check(c.isActive == true, "still active after adding display assertion")
c.setDisplayAwake(false)
check(c.isActive == true, "still active after removing display assertion (system never dropped)")
check(c.start(keepDisplayAwake: true) == true, "re-start is idempotent (new assertions before old are released)")
check(c.isActive == true, "still active after re-start")
c.stop()
check(c.isActive == false, "inactive after stop")
let c2 = KeepAwakeController()
c2.setDisplayAwake(true)
check(c2.isActive == false, "setDisplayAwake is a no-op while inactive")

print(failures == 0
      ? "\n✅ All checks passed (\(groups) groups)"
      : "\n❌ \(failures) check(s) FAILED")
exit(failures == 0 ? 0 : 1)
