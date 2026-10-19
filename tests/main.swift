import Foundation
import ServiceManagement

let suite = "SwiftQuitTests.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message)
    checks += 1
}

let fresh = AppSettings(defaults: defaults)
check(fresh.showMenuBarIcon && fresh.closeDelay == 2 && fresh.ruleMode == .excludeApps,
      "A new installation must use safe defaults")
defaults.set(["launchAtLogin": "true", "launchHidden": "false", "menubarIconEnabled": "false",
              "excludeBehaviour": "includeApps", "closeDelay": "7", "futureKey": "preserve"],
             forKey: "SwiftQuitSettings")
defaults.set(["/Applications/Safari.app", "/Applications/Safari.app", "/Applications/Mail.app"],
             forKey: "SwiftQuitExcludedApps")
let settings = AppSettings(defaults: defaults)
check(!settings.showMenuBarIcon && settings.ruleMode == .includeApps && settings.closeDelay == 7,
      "Existing preferences must migrate")
check(settings.applicationPaths.count == 2, "Duplicate legacy paths must not break list selection")
settings.showMenuBarIcon = true
settings.closeDelay = 9
settings.applicationPaths.append("/Applications/Notes.app")
let restored = AppSettings(defaults: defaults)
check(restored.showMenuBarIcon && restored.closeDelay == 9 && restored.applicationPaths.count == 3,
      "Preferences must survive a restart")
check((defaults.dictionary(forKey: "SwiftQuitSettings") as? [String: String])?["futureKey"] == "preserve",
      "Saving preferences must preserve unrelated legacy keys")
defaults.set(["closeDelay": "-100", "excludeBehaviour": "invalid"], forKey: "SwiftQuitSettings")
check(AppSettings(defaults: defaults).closeDelay == 1, "Negative legacy delays must be safe")
check(AppSettings(defaults: defaults).ruleMode == .excludeApps, "Unknown modes must fall back safely")

final class FakeLoginItem: LoginItemClient {
    var status: SMAppService.Status = .notRegistered
    var failRegistration = false
    var cleanupSucceeds = true
    var registrations = 0
    var removals = 0
    var cleanups = 0
    func register() throws {
        registrations += 1
        if failRegistration { throw NSError(domain: "test", code: 1) }
        status = .requiresApproval
    }
    func unregister() throws { removals += 1; status = .notRegistered }
    func disableLegacyHelper() -> Bool { cleanups += 1; return cleanupSucceeds }
}

defaults.set(["launchAtLogin": "true"], forKey: "SwiftQuitSettings")
let client = FakeLoginItem()
let login = LoginItemService(client: client, defaults: defaults)
client.failRegistration = true
login.migrateIfNeeded()
check(login.errorMessage != nil && !login.isRegistered && client.cleanups == 0,
      "Registration failure must retain the legacy helper")
check(!defaults.bool(forKey: "SwiftQuitLoginItemMigrated"), "Failed migration must remain retryable")
client.failRegistration = false
login.migrateIfNeeded()
check(login.status == .requiresApproval && login.isRegistered, "Pending approval must be represented accurately")
check(client.cleanups == 1 && defaults.bool(forKey: "SwiftQuitLoginItemMigrated"),
      "Successful migration must disable the legacy helper")
let registrations = client.registrations
login.migrateIfNeeded()
check(client.registrations == registrations, "Migration must not repeat after success")
client.status = .notRegistered
login.refresh()
check(!login.isRegistered, "External changes in System Settings must be reflected")
login.setEnabled(false)
check(client.removals == 0, "Disabling an already disabled service must be harmless")

defaults.set(false, forKey: "SwiftQuitLoginItemMigrated")
defaults.set(["launchAtLogin": "true"], forKey: "SwiftQuitSettings")
client.status = .enabled
client.cleanupSucceeds = false
login.setEnabled(false)
check(client.removals == 1 && defaults.bool(forKey: "SwiftQuitLegacyLoginCleanupPending"),
      "Cleanup failures must be recorded even when disabling startup")
client.cleanupSucceeds = true
login.migrateIfNeeded()
check(client.status == .notRegistered && defaults.bool(forKey: "SwiftQuitLoginItemMigrated"),
      "Retrying helper cleanup must not re-enable startup")
print("Passed \(checks) settings and login migration checks")
