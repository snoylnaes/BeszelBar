import SwiftUI
import AppKit

@Observable
@MainActor
final class MenuHighlight {
    static let shared = MenuHighlight()

    /// The `representedObject` of the highlighted item, when it is a string.
    var highlightedID: String?

    /// The `representedObject` of the highlighted item in a system submenu.
    /// It is separate from `highlightedID` so that the system row stays highlighted while its submenu is open.
    var submenuHighlightedID: String?
}

/// Menu delegate for the system submenus. It tracks `MenuHighlight.submenuHighlightedID`.
@MainActor
final class SubmenuHighlightDelegate: NSObject, NSMenuDelegate {
    static let shared = SubmenuHighlightDelegate()

    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        MenuHighlight.shared.submenuHighlightedID = item?.representedObject as? String
    }

    func menuDidClose(_ menu: NSMenu) {
        MenuHighlight.shared.submenuHighlightedID = nil
    }
}

@MainActor
enum MenuBuilder {
    private static let menuWidth: CGFloat = 320

    /// Replaces the items of `menu` with items built from the current state.
    static func populate(_ menu: NSMenu, appState: AppState) {
        menu.removeAllItems()
        menu.autoenablesItems = false

        let headerItem = NSMenuItem()
        let headerView = NSHostingView(rootView: MenuHeaderView(
            appState: appState,
            toggleHubList: { [weak menu] isOpen in
                guard let menu else { return }
                if isOpen {
                    for (offset, item) in hubListItems(appState: appState, menu: menu).enumerated() {
                        menu.insertItem(item, at: 1 + offset)
                    }
                } else {
                    for item in menu.items where item.tag == hubListTag {
                        menu.removeItem(item)
                    }
                }
            },
            refresh: { [weak menu] in
                menu?.cancelTracking()
                RefreshService.shared.refresh()
            },
            openSettings: { [weak menu] in
                menu?.cancelTracking()
                WindowManager.shared.showSettings()
            }
        ))
        headerView.frame = NSRect(x: 0, y: 0, width: menuWidth, height: headerView.fittingSize.height)
        headerItem.view = headerView
        menu.addItem(headerItem)

        if !appState.activeAlerts.isEmpty {
            menu.addItem(createAlertsSubmenu(alerts: appState.activeAlerts, systems: appState.selectedInstanceSystems))
            menu.addItem(NSMenuItem.separator())
        }

        if appState.instances.isEmpty {
            menu.addItem(createInfoItem("No Hub Configured", subtext: "Open Settings to add a hub"))
        } else if appState.selectedInstanceSystems.isEmpty && appState.isLoading {
            let item = NSMenuItem(title: "Loading...", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        } else if appState.selectedInstanceSystems.isEmpty {
            menu.addItem(createInfoItem("No Systems Found", subtext: "Check your hub configuration"))
        } else if appState.visibleSystems.isEmpty {
            menu.addItem(createInfoItem("All Systems Hidden", subtext: "Choose systems to show in Settings"))
        } else {
            for system in appState.menuSystems {
                let item = createSystemItem(for: system, appState: appState)
                menu.addItem(item)
            }

            let overflow = appState.visibleSystems.count - AppState.menuSystemLimit
            if overflow > 0 {
                let more = NSMenuItem(title: "+\(overflow) more systems", action: nil, keyEquivalent: "")
                more.isEnabled = false
                more.attributedTitle = NSAttributedString(
                    string: "+\(overflow) more systems",
                    attributes: [.foregroundColor: NSColor.secondaryLabelColor]
                )
                menu.addItem(more)
            }
        }

        addShortcut("Settings...", action: #selector(MenuActions.openSettings), key: ",", to: menu)
        addShortcut("Refresh Now", action: #selector(MenuActions.refreshNow), key: "r", to: menu)
        addShortcut("Quit BeszelBar", action: #selector(MenuActions.quit), key: "q", to: menu)
    }

    /// Adds a hidden item so that its key equivalent works while the menu is open.
    private static func addShortcut(_ title: String, action: Selector, key: String, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = MenuActions.shared
        item.isHidden = true
        item.allowsKeyEquivalentWhenHidden = true
        menu.addItem(item)
    }

    /// Tag of the hub list items that the header inserts under itself.
    private static let hubListTag = 1

    private static func hubListItems(appState: AppState, menu: NSMenu) -> [NSMenuItem] {
        func row(_ id: String, _ title: String, isSelected: Bool = false, action: @escaping () -> Void) -> NSMenuItem {
            let item = NSMenuItem()
            item.tag = hubListTag
            item.representedObject = id
            item.view = NSHostingView(rootView: HubMenuRowView(id: id, title: title, isSelected: isSelected) { [weak menu] in
                menu?.cancelTracking()
                action()
            })
            item.view?.frame = NSRect(x: 0, y: 0, width: menuWidth, height: 26)
            return item
        }

        var items = appState.instances.map { instance in
            row("hub:\(instance.id)", instance.name.isEmpty ? instance.url : instance.name,
                isSelected: instance.id == appState.selectedInstance?.id) {
                AppState.shared.selectInstance(instance)
            }
        }
        items.append(row("hub:manage", "Manage Hubs...") {
            WindowManager.shared.showSettings(tab: .hubs)
        })

        let separator = NSMenuItem.separator()
        separator.tag = hubListTag
        items.append(separator)
        return items
    }

    private static func createAlertsSubmenu(alerts: [AlertRecord], systems: [SystemRecord]) -> NSMenuItem {
        let item = NSMenuItem(title: "Alerts (\(alerts.count))", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: nil)
        item.image?.size = NSSize(width: 14, height: 14)
        item.image?.isTemplate = false

        let submenu = NSMenu()

        for alert in alerts.prefix(10) {
            let systemName = systems.first(where: { $0.id == alert.system })?.name ?? alert.system ?? "Unknown"
            let alertItem = NSMenuItem()

            let view = NSHostingView(rootView: AlertMenuRowView(alert: alert, systemName: systemName))
            view.frame = NSRect(x: 0, y: 0, width: menuWidth - 20, height: 44)
            alertItem.view = view

            submenu.addItem(alertItem)
        }

        if alerts.count > 10 {
            submenu.addItem(NSMenuItem.separator())
            let moreItem = NSMenuItem(title: "+\(alerts.count - 10) more alerts", action: nil, keyEquivalent: "")
            moreItem.isEnabled = false
            submenu.addItem(moreItem)
        }

        item.submenu = submenu
        return item
    }

    private static func createInfoItem(_ title: String, subtext: String?) -> NSMenuItem {
        let item = NSMenuItem()
        let view = NSHostingView(rootView: InfoMenuRowView(title: title, subtext: subtext))
        view.frame = NSRect(x: 0, y: 0, width: menuWidth, height: subtext != nil ? 40 : 28)
        item.view = view
        item.isEnabled = true
        return item
    }

    private static func createSystemItem(for system: SystemRecord, appState: AppState) -> NSMenuItem {
        let item = NSMenuItem(
            title: system.name.isEmpty ? system.id : system.name,
            action: #selector(MenuActions.openSystemInBrowser(_:)),
            keyEquivalent: ""
        )
        item.target = MenuActions.shared
        item.representedObject = system.id

        let hostingView = NSHostingView(rootView: SystemMenuRowView(system: system))
        hostingView.frame = NSRect(x: 0, y: 0, width: menuWidth, height: 44)

        let wrapper = NSView(frame: hostingView.frame)
        wrapper.wantsLayer = true
        wrapper.layer?.backgroundColor = .clear
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear
        wrapper.addSubview(hostingView)
        hostingView.frame = wrapper.bounds

        item.view = wrapper

        let containers = appState.containers[system.id] ?? []
        let submenu = createSystemSubmenu(for: system, containers: containers, appState: appState)
        item.submenu = submenu

        return item
    }

    private static var defaultBrowserIsSafari: Bool {
        guard let probe = URL(string: "https://example.com"),
              let browser = NSWorkspace.shared.urlForApplication(toOpen: probe) else { return false }
        return Bundle(url: browser)?.bundleIdentifier == "com.apple.Safari"
    }

    private static func createSystemSubmenu(for system: SystemRecord, containers: [ContainerRecord], appState: AppState) -> NSMenu {
        let submenu = NSMenu()
        submenu.delegate = SubmenuHighlightDelegate.shared

        let details = appState.systemDetails[system.id]

        let detailItem = NSMenuItem()
        let detailView = NSHostingView(rootView: SystemDetailView(
            system: system,
            details: details,
            charts: appState.charts(for: system.id),
            titles: appState.chartTitles[system.id] ?? [:],
            openInBrowser: { [weak detailItem] in
                MenuActions.openSystem(system.id)
                var menu = detailItem?.menu
                while let parent = menu?.supermenu { menu = parent }
                menu?.cancelTracking()
            },
            browserSymbol: defaultBrowserIsSafari ? "safari" : "globe"
        ))
        detailView.frame = NSRect(origin: .zero, size: detailView.fittingSize)
        detailItem.view = detailView
        submenu.addItem(detailItem)

        if !containers.isEmpty {
            let sortedContainers = containers.sorted { $0.name.lowercased() < $1.name.lowercased() }

            let containersID = "containers:\(system.id)"
            let containersItem = NSMenuItem()
            containersItem.representedObject = containersID
            let rowView = NSHostingView(rootView: ContainersMenuRowView(id: containersID, containers: containers))
            rowView.frame = NSRect(x: 0, y: 0, width: ChartLayout.panelWidth, height: 28)
            containersItem.view = rowView

            let listItem = NSMenuItem()
            let listView = NSHostingView(rootView: ContainerListView(containers: sortedContainers))
            listView.frame = NSRect(origin: .zero, size: listView.fittingSize)
            listItem.view = listView
            let containersSubmenu = NSMenu()
            containersSubmenu.addItem(listItem)
            containersItem.submenu = containersSubmenu
            submenu.addItem(containersItem)
        }

        return submenu
    }
}
