import Cocoa
import Carbon
import SwiftUI
import Combine
import AXSwift
import Swindler

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = AppSettings.shared
    private let loginItems = LoginItemService()
    private let runtime = RuntimeStatus()
    private var settingsWindow: NSWindowController?
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var subscriptions = Set<AnyCancellable>()
    private var state: Swindler.State?
    private var initializing = false
    private var permissionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadMenu()
        settings.$showMenuBarIcon.sink { [weak self] visible in
            self?.updateMenuVisibility(preference: visible)
        }.store(in: &subscriptions)
        runtime.$message.sink { [weak self] message in
            self?.statusMenuItem.title = message
        }.store(in: &subscriptions)
        loginItems.migrateIfNeeded()
        startMonitoringIfAuthorized()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.startMonitoringIfAuthorized()
        }

        // The system marks login launches through the launch Apple event.
        // --background also provides a repeatable way to verify quiet launch locally.
        let launchedAtLogin = NSAppleEventManager.shared().currentAppleEvent?
            .paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
        if !launchedAtLogin && !ProcessInfo.processInfo.arguments.contains("--background") {
            openSettings()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return false
    }

    private func startMonitoringIfAuthorized() {
        let trusted = AXSwift.checkIsProcessTrusted(prompt: false)
        runtime.accessibilityGranted = trusted
        updateMenuVisibility(preference: settings.showMenuBarIcon)
        guard trusted else {
            runtime.message = "Accessibility access needed"
            return
        }
        if state != nil {
            runtime.message = "Automatic quitting is active"
            return
        }
        guard !initializing else { return }
        initializing = true
        runtime.message = "Starting…"
        Swindler.initialize().done { [weak self] state in
            guard let self = self else { return }
            self.state = state
            self.initializing = false
            SwiftQuit.activateAutomaticAppClosing(state: state)
            self.runtime.message = "Automatic quitting is active"
        }.catch { [weak self] error in
            self?.initializing = false
            self?.runtime.message = "Unable to monitor windows"
            NSLog("Swift Quit initialization failed: %@", String(describing: error))
        }
    }

    private func loadMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(named: "MenuIcon")
        statusItem.button?.image?.size = NSSize(width: 18, height: 18)
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip = "Swift Quit"
        let menu = NSMenu()
        statusMenuItem = NSMenuItem(title: runtime.message, action: nil, keyEquivalent: "")
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem(title: "Quit Swift Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func updateMenuVisibility(preference: Bool) {
        // Leave a recovery entry point while Accessibility is unavailable.
        statusItem?.isVisible = preference || !runtime.accessibilityGranted
    }

    @objc func openSettings() {
        loginItems.refresh()
        startMonitoringIfAuthorized()
        if settingsWindow == nil {
            let view = SettingsView(settings: settings, loginItems: loginItems, runtime: runtime)
            let window = NSWindow(contentViewController: NSHostingController(rootView: view))
            window.title = "Swift Quit Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 560, height: 740))
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = NSWindowController(window: window)
        }
        settingsWindow?.showWindow(self)
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class RuntimeStatus: ObservableObject {
    @Published var accessibilityGranted = false
    @Published var message = "Starting…"
}
