# Espresso ☕

A tiny, native **menu-bar app for Apple Silicon Macs** that keeps your Mac awake —
indefinitely or for a set time — with an espresso-cup icon whose crema **drains** as
the timer counts down. No Dock icon, no clutter.

## Features (v1)
- Keep awake **indefinitely** or for a **timed brew** — coffee-named presets
  (Ristretto · 15m, Espresso · 30m, Doppio · 1h, Lungo · 2h, Americano · 5h, Bottomless) plus a
  custom hours+minutes popover.
- Live **countdown** in the menu bar; the espresso cup **drains** as time runs out.
- Optional **keep the display awake too** (otherwise only the system stays awake).
- **Battery safety:** auto-let-it-nap when on battery and the charge drops to a chosen
  threshold (default 20%) — a forgotten session can't drain you flat.
- **Launch at login**.
- A cute cup **mascot** app icon (awake / napping). Menu-bar only — no Dock icon.

## How it works
Uses IOKit **power assertions** (`IOPMAssertionCreateWithName`) — the same mechanism as
macOS's built-in `caffeinate`. `PreventUserIdleSystemSleep` keeps the system awake while
allowing the display to sleep; `PreventUserIdleDisplaySleep` is added when "keep display
awake" is on. Assertions are always released on quit.

## Requirements
- macOS 13 (Ventura) or later, Apple Silicon.
- Swift toolchain (Xcode or Command Line Tools).

## Build & run
```sh
cd Espresso
scripts/build_app.sh          # produces Espresso.app (ad-hoc signed)
open Espresso.app             # launches into the menu bar
```

## Run the tests
```sh
swift run EspressoTests     # dependency-free runner; exits non-zero on failure
```
(XCTest/Swift-Testing need full Xcode, so tests live in a plain executable target that
imports `EspressoKit` — covers time formatting, the battery-nap decision, and the IOKit
assertion lifecycle.)

## Verify the core mechanism (no UI)
```sh
swift run Espresso --selftest
# prints `pmset -g assertions` before/after creating + releasing assertions
```

## Preview the icon glyph
```sh
swift run Espresso --render-icons /tmp/espresso-icons
open /tmp/espresso-icons      # PNGs of the cup at several fill levels, both states
```

## Project layout
```
Package.swift                 swift-tools 5.9, macOS 13+; 3 targets
Sources/EspressoKit/          pure, testable logic (no AppKit)
  TimeFormatting.swift        abbreviated / clock formatting
  BatteryGuard.swift          power-source snapshot + nap decision
  KeepAwakeController.swift    IOKit power assertions (system + display)
Sources/Espresso/             the menu-bar app (depends on EspressoKit)
  EspressoMain.swift          @main entry + hidden dev modes (--selftest/--render-icons/--make-icon/--activate)
  AppDelegate.swift           status item, menu, state machine, battery timer, actions
  SessionTimer.swift          1s countdown on the main run loop
  CupIconRenderer.swift       template espresso-cup glyph at a fill level
  MascotRenderer.swift        full-color cup mascot → AppIcon.icns
  DurationPopover.swift       custom hours+minutes popover
  Settings.swift              UserDefaults-backed prefs
  LaunchAtLogin.swift         SMAppService wrapper
  SelfTest.swift              --selftest / --render-icons / --make-icon implementations
Tests/EspressoTests/main.swift  dependency-free test runner
scripts/build_app.sh          builds + bundles Espresso.app (ad-hoc signed)
Espresso.entitlements         App Store sandbox build (not used for the local build)
AppStore/APPSTORE.md          listing copy + submission checklist
```

## Roadmap
- **Distribution:** currently personal/local (ad-hoc signed). Sandbox-clean and ready to
  graduate to the Mac App Store ($1.99) — see `AppStore/APPSTORE.md`.
- **v2 ideas:** auto-activate while chosen apps run (Zoom/exports), global hotkey,
  low-battery banner via notifications.
