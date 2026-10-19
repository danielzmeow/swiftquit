import SwiftUI
import AppKit
import ServiceManagement
import AXSwift

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var loginItems: LoginItemService
    @ObservedObject var runtime: RuntimeStatus

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Label(runtime.accessibilityGranted ? "Authorized" : "Permission needed",
                          systemImage: runtime.accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle")
                        .foregroundStyle(runtime.accessibilityGranted ? Color.secondary : Color.orange)
                } label: {
                    Text("Accessibility")
                    Text("Required to detect when application windows close.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if !runtime.accessibilityGranted {
                    Button("Open Accessibility Settings…") {
                        _ = AXSwift.checkIsProcessTrusted(prompt: true)
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                }
                LabeledContent("Status", value: runtime.message)
            } header: {
                Label("Swift Quit", systemImage: "macwindow")
            }

            Section("General") {
                Toggle(isOn: Binding(get: { loginItems.isRegistered }, set: loginItems.setEnabled)) {
                    Text("Launch at login")
                    Text(loginItems.detail).font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityLabel("Launch at login")
                .accessibilityValue(loginItems.isRegistered ? "On" : "Off")
                if loginItems.status == .requiresApproval {
                    Button("Open Login Items…") { SMAppService.openSystemSettingsLoginItems() }
                }
                Toggle(isOn: $settings.showMenuBarIcon) {
                    Text("Show menu bar icon")
                    Text("Open Swift Quit from Applications to return to settings.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .accessibilityLabel("Show menu bar icon")
                if !settings.showMenuBarIcon && !runtime.accessibilityGranted {
                    Text("The icon stays visible until Accessibility is authorized.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Section {
                LabeledContent("Quit after") {
                    HStack(spacing: 6) {
                        TextField("", value: Binding(
                            get: { settings.closeDelay },
                            set: { settings.closeDelay = max(1, $0) }
                        ), format: .number.grouping(.never))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64)
                        .accessibilityLabel("Delay in seconds")
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        Text("seconds").foregroundStyle(.secondary)
                    }
                }
                Picker("Apply to", selection: $settings.ruleMode) {
                    ForEach(AppSettings.RuleMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            } header: {
                Text("Automatic Quitting")
            } footer: {
                Text("Apps quit after their last window closes. An app stays open if a new window appears during the delay.")
            }

            ApplicationsSection(settings: settings)
        }
        .formStyle(.grouped)
        .frame(minWidth: 560, minHeight: 650)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            loginItems.refresh()
        }
        .alert("Login Item", isPresented: Binding(
            get: { loginItems.errorMessage != nil },
            set: { if !$0 { loginItems.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { loginItems.errorMessage = nil }
        } message: {
            Text(loginItems.errorMessage ?? "")
        }
    }
}
