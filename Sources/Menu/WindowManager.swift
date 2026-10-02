import SwiftUI
import AppKit

@MainActor
final class WindowManager {
    static let shared = WindowManager()
    private var settingsWindow: NSWindow?

    private init() {}

    func showSettings(tab: SettingsTab? = nil) {
        if let existing = settingsWindow, existing.isVisible {
            if let tab {
                existing.contentView = NSHostingView(rootView: SettingsView(appState: AppState.shared, selectedTab: tab))
            }
            existing.orderFrontRegardless()
            return
        }

        let settingsView = SettingsView(appState: AppState.shared, selectedTab: tab ?? .general)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 540),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "BeszelBar"
        window.contentView = NSHostingView(rootView: settingsView)
        window.isReleasedWhenClosed = false
        window.center()

        settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
