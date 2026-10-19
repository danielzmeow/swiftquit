import Foundation
import Combine

/// Keeps the existing defaults keys so upgrades preserve application rules.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    enum RuleMode: String, CaseIterable, Identifiable {
        case excludeApps, includeApps
        var id: String { rawValue }
        var title: String {
            self == .excludeApps ? "All apps except those listed" : "Only the apps listed"
        }
    }

    @Published var showMenuBarIcon: Bool { didSet { save() } }
    @Published var ruleMode: RuleMode { didSet { save() } }
    @Published var closeDelay: Int { didSet { save() } }
    @Published var applicationPaths: [String] {
        didSet { defaults.set(applicationPaths, forKey: "SwiftQuitExcludedApps") }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let old = defaults.dictionary(forKey: "SwiftQuitSettings") as? [String: String] ?? [:]
        showMenuBarIcon = old["menubarIconEnabled"] != "false"
        ruleMode = RuleMode(rawValue: old["excludeBehaviour"] ?? "") ?? .excludeApps
        closeDelay = max(1, Int(old["closeDelay"] ?? "") ?? 2)
        var seen = Set<String>()
        applicationPaths = (defaults.stringArray(forKey: "SwiftQuitExcludedApps") ?? []).filter { seen.insert($0).inserted }
    }

    private func save() {
        var values = defaults.dictionary(forKey: "SwiftQuitSettings") as? [String: String] ?? [:]
        values["menubarIconEnabled"] = String(showMenuBarIcon)
        values["excludeBehaviour"] = ruleMode.rawValue
        values["closeDelay"] = String(closeDelay)
        defaults.set(values, forKey: "SwiftQuitSettings")
    }
}
