import SwiftUI

struct SystemMenuRowView: View {
    let system: SystemRecord
    @AppStorage("showStatsInMenu") private var showStatsInMenu = true

    static let highlightInset: CGFloat = 5
    static let highlightCornerRadius: CGFloat = 5
    static let highlightOpacity = 0.08

    private var live: SystemRecord {
        AppState.shared.latest(system)
    }

    var body: some View {
        row
            .menuRowHighlight(MenuHighlight.shared.highlightedID == system.id)
    }

    private var row: some View {
        HStack(spacing: 8) {
            StatusDot(color: statusColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(live.name.isEmpty ? system.id : live.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                if showStatsInMenu, hasStats {
                    HStack(spacing: 4) {
                        if let cpu = live.cpuPercentage {
                            StatPill(value: "\(Int(cpu))%", icon: "cpu")
                        }
                        if let mem = live.memoryPercentage {
                            StatPill(value: "\(Int(mem))%", icon: "memorychip")
                        }
                        if let disk = live.diskPercentage {
                            StatPill(value: "\(Int(disk))%", icon: "internaldrive")
                        }
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.4))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }

    private var hasStats: Bool {
        live.cpuPercentage != nil || live.memoryPercentage != nil || live.diskPercentage != nil
    }

    private var statusColor: Color {
        guard let status = live.status?.lowercased() else { return .gray }
        switch status {
        case "up", "online": return AppColors.up
        case "down", "offline": return AppColors.down
        case "pending": return AppColors.pending
        default: return .gray
        }
    }
}

extension View {
    /// Fills the row with the grey highlight that marks the selected menu row.
    func menuRowHighlight(_ isHighlighted: Bool) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: SystemMenuRowView.highlightCornerRadius, style: .continuous)
                        .fill(Color.primary.opacity(SystemMenuRowView.highlightOpacity))
                        .padding(.horizontal, SystemMenuRowView.highlightInset)
                }
            }
    }
}

struct StatusDot: View {
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 12, height: 12)
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
        }
    }
}

struct StatPill: View {
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(value)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundColor(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.12))
        .clipShape(Capsule())
    }
}
