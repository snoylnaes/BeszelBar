import SwiftUI

struct MenuHeaderView: View {
    var appState: AppState
    var toggleHubList: (Bool) -> Void = { _ in }
    var refresh: () -> Void = {}
    var openSettings: () -> Void = {}

    @State private var isHubListOpen = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    if appState.instances.count > 1 {
                        Button {
                            isHubListOpen.toggle()
                            toggleHubList(isHubListOpen)
                        } label: {
                            HStack(spacing: 4) {
                                title
                                Image(systemName: isHubListOpen ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        title
                    }

                    if !appState.selectedInstanceSystems.isEmpty {
                        let online = appState.selectedInstanceSystems.filter { $0.isOnline }.count
                        let offline = appState.selectedInstanceSystems.count - online

                        HStack(spacing: 10) {
                            StatusCount(count: online, label: "up", color: AppColors.up)
                            if offline > 0 {
                                StatusCount(count: offline, label: "down", color: AppColors.down)
                            }
                        }
                    }
                }

                Spacer()

                HStack(spacing: 5) {
                    PanelIconButton(systemName: "arrow.clockwise", help: "Refresh Now", tooltipBeside: true, action: refresh)
                    PanelIconButton(systemName: "gearshape", help: "Settings", tooltipBeside: true, action: openSettings)
                }
            }
            .padding(.leading, 22)
            .padding(.trailing, 12)
            .padding(.vertical, 8)
            .zIndex(1)

            Divider()
                .padding(.horizontal, 10)
        }
        .frame(width: 320)
    }

    private var title: some View {
        Text(hubName)
            .font(.system(size: 13, weight: .semibold))
            .lineLimit(1)
    }

    private var hubName: String {
        guard let selected = appState.selectedInstance else { return "BeszelBar" }
        return selected.name.isEmpty ? selected.url : selected.name
    }
}

struct StatusCount: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(count) \(label)")
        }
        .font(.system(size: 10))
        .foregroundColor(.secondary)
    }
}

struct HubMenuRowView: View {
    let id: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 10)
                    .opacity(isSelected ? 1 : 0)
                Text(title)
                    .font(.system(size: 12))
                    .lineLimit(1)
                Spacer()
            }
            .padding(.leading, 6)
            .padding(.trailing, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .menuRowHighlight(MenuHighlight.shared.highlightedID == id)
    }
}
