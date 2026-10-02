import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var observationTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_: Notification) {
        UserDefaults.standard.register(defaults: [RefreshService.intervalKey: RefreshService.defaultInterval])

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        self.statusItem = item
        updateStatusButton()

        RefreshService.shared.restartTimer()
        RefreshService.shared.refresh()
        startObserving()

        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        RefreshService.shared.stop()
        observationTask?.cancel()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        MenuBuilder.populate(menu, appState: AppState.shared)
    }

    func menuWillOpen(_ menu: NSMenu) {
        RefreshService.shared.menuWillOpen()
    }

    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        MenuHighlight.shared.highlightedID = item?.representedObject as? String
    }

    func menuDidClose(_ menu: NSMenu) {
        MenuHighlight.shared.highlightedID = nil
        RefreshService.shared.menuDidClose()
    }

    private func startObserving() {
        observationTask = Task { @MainActor in
            while !Task.isCancelled {
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = AppState.shared.activeAlerts
                    } onChange: {
                        continuation.resume()
                    }
                }
                updateStatusButton()
            }
        }
    }

    private func updateStatusButton() {
        guard let button = statusItem?.button else { return }
        let alertCount = AppState.shared.activeAlerts.count
        if alertCount > 0 {
            button.image = NSImage(systemSymbolName: "server.rack.fill", accessibilityDescription: "BeszelBar")
            button.title = " \(alertCount)"
        } else {
            button.image = NSImage(systemSymbolName: "server.rack", accessibilityDescription: "BeszelBar")
            button.title = ""
        }
        button.image?.size = NSSize(width: 18, height: 18)
    }
}
