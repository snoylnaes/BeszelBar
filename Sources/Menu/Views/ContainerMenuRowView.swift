import SwiftUI

/// The row at the bottom of a system submenu that opens the container list.
struct ContainersMenuRowView: View {
    let id: String
    let containers: [ContainerRecord]

    private var unhealthyCount: Int {
        containers.filter { $0.health == .unhealthy }.count
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "shippingbox")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Text("Containers")
                .font(.system(size: 12, weight: .medium))

            Spacer()

            if unhealthyCount > 0 {
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppColors.down)
                        .frame(width: 6, height: 6)
                    Text("\(unhealthyCount) unhealthy")
                }
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            }

            Text("\(containers.count)")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary.opacity(0.4))
        }
        .padding(.horizontal, ChartLayout.panelPadding + ChartLayout.cardPadding)
        .menuRowHighlight(MenuHighlight.shared.submenuHighlightedID == id, inset: ChartLayout.panelPadding)
    }
}

/// The container list in the submenu of the containers row.
struct ContainerListView: View {
    let containers: [ContainerRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(containers.enumerated()), id: \.element.id) { index, container in
                if index > 0 {
                    Divider()
                        .padding(.vertical, 6)
                }
                row(container)
            }
        }
        .chartCard()
        .padding(ChartLayout.panelPadding)
        .frame(width: ChartLayout.panelWidth)
    }

    private func row(_ container: ContainerRecord) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Circle()
                    .fill(container.health.dotColor)
                    .frame(width: 6, height: 6)
                Text(container.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text("\(UnitFormat.number(container.cpu))%  ·  \(UnitFormat.compact(container.memory, units: ["MB", "GB", "TB"]))")
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }

            HStack {
                Text(container.image)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text(container.status)
                    .lineLimit(1)
            }
            .font(.system(size: 9))
            .foregroundColor(.secondary)
            .padding(.leading, 12)
        }
    }
}

private extension ContainerHealth {
    var dotColor: Color {
        switch self {
        case .none: return AppColors.inactive
        case .starting: return AppColors.pending
        case .healthy: return AppColors.up
        case .unhealthy: return AppColors.down
        }
    }
}
