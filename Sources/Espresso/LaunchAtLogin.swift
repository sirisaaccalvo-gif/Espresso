import Foundation
import ServiceManagement

/// Launch-at-login via the modern `SMAppService` API (macOS 13+). No helper bundle
/// or `SMLoginItemSetEnabled` plumbing required.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("Espresso: launch-at-login \(enabled ? "register" : "unregister") failed: \(error)")
            return false
        }
    }
}
