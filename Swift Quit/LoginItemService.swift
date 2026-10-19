import Combine
import Foundation
import ServiceManagement

protocol LoginItemClient {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() throws
    func disableLegacyHelper() -> Bool
}

private struct SystemLoginItemClient: LoginItemClient {
    var status: SMAppService.Status { SMAppService.mainApp.status }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() throws { try SMAppService.mainApp.unregister() }
    func disableLegacyHelper() -> Bool {
        guard let identifier = Bundle.main.bundleIdentifier else { return false }
        return SMLoginItemSetEnabled((identifier + "-LaunchAtLoginHelper") as CFString, false)
    }
}

final class LoginItemService: ObservableObject {
    @Published private(set) var status: SMAppService.Status
    @Published var errorMessage: String?
    private let client: LoginItemClient
    private let defaults: UserDefaults

    init(client: LoginItemClient? = nil, defaults: UserDefaults = .standard) {
        let client = client ?? SystemLoginItemClient()
        self.client = client
        self.defaults = defaults
        self.status = client.status
    }

    var isRegistered: Bool { status == .enabled || status == .requiresApproval }
    var detail: String {
        switch status {
        case .enabled: return "Starts quietly when you log in."
        case .requiresApproval: return "Allow Swift Quit in System Settings → General → Login Items."
        case .notFound: return "Move Swift Quit to Applications, then try again."
        default: return "Start Swift Quit automatically after signing in."
        }
    }

    func refresh() { status = client.status }

    func setEnabled(_ enabled: Bool) {
        refresh()
        errorMessage = nil
        do {
            if enabled && !isRegistered { try client.register() }
            else if !enabled && isRegistered { try client.unregister() }
            refresh()
            var values = defaults.dictionary(forKey: "SwiftQuitSettings") as? [String: String] ?? [:]
            let needsCleanup = defaults.bool(forKey: "SwiftQuitLegacyLoginCleanupPending") ||
                (values["launchAtLogin"] == "true" && !defaults.bool(forKey: "SwiftQuitLoginItemMigrated"))
            let cleanedUp = !needsCleanup || client.disableLegacyHelper()
            recordCleanupResult(cleanedUp)
            values["launchAtLogin"] = String(enabled)
            defaults.set(values, forKey: "SwiftQuitSettings")
        } catch {
            refresh()
            errorMessage = error.localizedDescription
        }
    }

    func migrateIfNeeded() {
        guard !defaults.bool(forKey: "SwiftQuitLoginItemMigrated") else { return }
        let old = defaults.dictionary(forKey: "SwiftQuitSettings") as? [String: String]
        if old?["launchAtLogin"] == "true" {
            // Keep retrying a failed migration; never silently discard the old preference.
            setEnabled(true)
        } else if defaults.bool(forKey: "SwiftQuitLegacyLoginCleanupPending") {
            // A user may disable login startup while legacy cleanup still needs retrying.
            recordCleanupResult(client.disableLegacyHelper())
        }
    }

    private func recordCleanupResult(_ succeeded: Bool) {
        defaults.set(succeeded, forKey: "SwiftQuitLoginItemMigrated")
        defaults.set(!succeeded, forKey: "SwiftQuitLegacyLoginCleanupPending")
        if !succeeded {
            errorMessage = "The previous login helper could not be disabled. Remove its entry in System Settings → General → Login Items."
        }
    }
}
