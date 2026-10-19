import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ApplicationsSection: View {
    @ObservedObject var settings: AppSettings
    @State private var selection = Set<String>()

    var body: some View {
        Section {
            if settings.applicationPaths.isEmpty {
                VStack(spacing: 6) {
                    Text("No applications added")
                    Text(settings.ruleMode == .excludeApps
                         ? "Automatic quitting applies to all eligible apps."
                         : "Add an application to enable automatic quitting for it.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 90)
            } else {
                List(selection: $selection) {
                    ForEach(settings.applicationPaths, id: \.self) { path in
                        ApplicationRow(path: path).tag(path)
                    }
                }
                .listStyle(.inset)
                .frame(height: 150)
                .accessibilityLabel("Application rules")
            }
            HStack {
                Button(action: addApplications) {
                    Label("Add…", systemImage: "plus")
                }
                Button(role: .destructive) {
                    settings.applicationPaths.removeAll { selection.contains($0) }
                    selection.removeAll()
                } label: {
                    Label("Remove", systemImage: "minus")
                }
                .disabled(selection.isEmpty)
                Spacer()
                Text("\(settings.applicationPaths.count) \(settings.applicationPaths.count == 1 ? "app" : "apps")")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } header: {
            Text(settings.ruleMode == .excludeApps ? "Excluded Applications" : "Included Applications")
        }
    }

    private func addApplications() {
        let panel = NSOpenPanel()
        panel.title = "Choose Applications"
        panel.allowedContentTypes = [.applicationBundle]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: { $0.isVisible && !$0.isSheet }) else { return }
        panel.beginSheetModal(for: window) { response in
            guard response == .OK else { return }
            for url in panel.urls where !settings.applicationPaths.contains(url.path) {
                settings.applicationPaths.append(url.path)
            }
        }
    }
}

private struct ApplicationRow: View {
    let path: String
    private var name: String { FileManager.default.displayName(atPath: path) }

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable().frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).lineLimit(1)
                Text(path).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
        }
        .padding(.vertical, 3)
        .help(path)
        .accessibilityElement(children: .combine)
    }
}
