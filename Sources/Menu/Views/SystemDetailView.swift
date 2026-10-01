import SwiftUI
import Charts

struct SystemDetailView: View {
    let system: SystemRecord
    var details: SystemDetailsRecord? = nil

    private var cpuModel: String? {
        details?.cpu ?? system.info?.m
    }

    private var cpuCores: Int? {
        details?.cores ?? system.info?.c
    }

    private var hostname: String? {
        details?.hostname ?? system.info?.h
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    let displayName = hostname ?? system.name
                    Label {
                        Text(displayName)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "desktopcomputer")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)

                    Spacer()
                }

                if cpuModel != nil || cpuCores != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(.system(size: 9))
                        if let model = cpuModel {
                            Text(model)
                                .lineLimit(1)
                        }
                        if let cores = cpuCores {
                            if cpuModel != nil {
                                Text("•")
                            }
                            Text("\(cores) cores")
                        }
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                }

                if system.info?.dt != nil || system.info?.u != nil {
                    HStack(spacing: 12) {
                        if let temp = system.info?.dt {
                            Label(String(format: "%.0f°C", temp), systemImage: "thermometer.medium")
                                .foregroundColor(temp > 80 ? .red : (temp > 60 ? .orange : .secondary))
                        }
                        if let uptime = system.info?.u {
                            Label(formatUptime(uptime), systemImage: "clock")
                                .foregroundColor(.secondary)
                        }
                    }
                    .font(.system(size: 10))
                }
            }

            Divider()
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 6) {
                Label("Usage", systemImage: "chart.bar.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)

                let history = AppState.shared.history[system.id] ?? []
                let latest = history.last
                if let cpu = latest?.cpu ?? system.cpuPercentage {
                    MetricChart(
                        label: "CPU",
                        percent: cpu,
                        detail: nil,
                        color: ChartPalette.cpu,
                        samples: history.compactMap { point in
                            point.cpu.map { ChartSample(date: point.date, value: $0, stacked: nil) }
                        },
                        yMax: nil,
                        format: { String(format: "%.0f%%", $0) }
                    )
                }
                if let mem = latest?.mem ?? system.memoryPercentage {
                    MetricChart(
                        label: "Memory",
                        percent: mem,
                        detail: usageDetail(used: latest?.memUsed, total: latest?.memTotal),
                        color: ChartPalette.memory,
                        samples: history.compactMap { point in
                            point.memUsed.map { ChartSample(date: point.date, value: $0, stacked: point.memCache) }
                        },
                        yMax: latest?.memTotal,
                        format: { String(format: "%.0f GB", $0) }
                    )
                }
                if let disk = latest?.disk ?? system.diskPercentage {
                    MetricChart(
                        label: "Disk",
                        percent: disk,
                        detail: usageDetail(used: latest?.diskUsed, total: latest?.diskTotal),
                        color: ChartPalette.disk,
                        samples: history.compactMap { point in
                            point.diskUsed.map { ChartSample(date: point.date, value: $0, stacked: nil) }
                        },
                        yMax: latest?.diskTotal,
                        format: { String(format: "%.0f GB", $0) }
                    )
                }
                if let latest, latest.netSent != nil || latest.netRecv != nil {
                    NetworkChart(
                        samples: history.map {
                            NetworkSample(date: $0.date, sent: $0.netSent ?? 0, received: $0.netRecv ?? 0)
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(width: 270)
    }

    private func usageDetail(used: Double?, total: Double?) -> String? {
        guard let used, let total else { return nil }
        return String(format: "%.1f / %.1f GB", used, total)
    }

    private func formatUptime(_ seconds: Double) -> String {
        let days = Int(seconds) / 86400
        let hours = (Int(seconds) % 86400) / 3600
        if days > 0 {
            return "\(days)d \(hours)h"
        } else {
            let mins = (Int(seconds) % 3600) / 60
            return "\(hours)h \(mins)m"
        }
    }

    private func formatBandwidth(_ mb: Double) -> String {
        if mb >= 1024 {
            return String(format: "%.1f GB/s", mb / 1024)
        }
        return String(format: "%.1f MB/s", mb)
    }

}

enum AppColors {
    static let green = Color.green
    static let orange = Color.orange
    static let red = Color.red
    static let gray = Color.gray

    static func level(_ value: Double) -> Color {
        if value >= 90 { return red }
        if value >= 70 { return orange }
        return green
    }
}

enum ChartPalette {
    static let cpu = Color(red: 55 / 255, green: 97 / 255, blue: 210 / 255)
    static let memory = Color(red: 75 / 255, green: 180 / 255, blue: 140 / 255)
    static let disk = Color(red: 164 / 255, green: 92 / 255, blue: 212 / 255)
    static let sent = Color(red: 208 / 255, green: 70 / 255, blue: 112 / 255)
    static let received = Color(red: 92 / 255, green: 181 / 255, blue: 141 / 255)
}

struct ChartSample: Identifiable {
    let date: Date
    let value: Double
    let stacked: Double?

    var id: Date { date }
}

struct ChartTimeAxis {
    let range: ClosedRange<Date>

    init(dates: [Date]) {
        let start = dates.first ?? Date().addingTimeInterval(-3600)
        let end = max(dates.last ?? Date(), start.addingTimeInterval(1))
        range = start...end
    }

    var ticks: [Date] {
        let step = 15.0 * 60
        var tick = (range.lowerBound.timeIntervalSince1970 / step).rounded(.up) * step
        var ticks: [Date] = []
        while tick <= range.upperBound.timeIntervalSince1970 {
            ticks.append(Date(timeIntervalSince1970: tick))
            tick += step
        }
        return ticks
    }

    func labelShift(for date: Date) -> CGFloat {
        let span = range.upperBound.timeIntervalSince(range.lowerBound)
        let plotWidth: CGFloat = 225
        let halfLabel: CGFloat = 19
        let fromLeft = CGFloat(date.timeIntervalSince(range.lowerBound) / span) * plotWidth
        let fromRight = plotWidth - fromLeft
        if fromLeft < halfLabel { return halfLabel - fromLeft }
        if fromRight < halfLabel { return fromRight - halfLabel }
        return 0
    }
}

extension Chart {
    func metricAxes(time: ChartTimeAxis, axisMax: Double, format: @escaping (Double) -> String) -> some View {
        self
            .chartXScale(domain: time.range)
            .chartYScale(domain: 0...axisMax)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, axisMax / 2, axisMax]) { value in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            Text(format(number)).font(.system(size: 8))
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: time.ticks) { value in
                    AxisTick(length: 5).foregroundStyle(Color.secondary.opacity(0.6))
                    AxisValueLabel(centered: false, anchor: .top, collisionResolution: .disabled) {
                        if let date = value.as(Date.self) {
                            Text(date, format: .dateTime.hour().minute())
                                .font(.system(size: 8))
                                .fixedSize()
                                .offset(x: time.labelShift(for: date), y: -2)
                        }
                    }
                }
            }
            .frame(height: 72)
    }
}

struct MetricChart: View {
    let label: String
    let percent: Double
    let detail: String?
    let color: Color
    let samples: [ChartSample]
    let yMax: Double?
    let format: (Double) -> String

    private var axisMax: Double {
        if let yMax, yMax > 0 { return yMax }
        let peak = samples.map { $0.value + ($0.stacked ?? 0) }.max() ?? 0
        return max(10, peak.rounded(.up))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Text("\(Int(percent))%")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundColor(percent >= 70 ? AppColors.level(percent) : .primary)
                Spacer()
                if let detail {
                    Text(detail)
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundColor(.secondary)
                }
            }

            Chart(samples) { sample in
                AreaMark(x: .value("Time", sample.date), y: .value(label, sample.value), series: .value("Layer", "base"))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(color.opacity(0.4))
                if let stacked = sample.stacked {
                    AreaMark(x: .value("Time", sample.date), y: .value(label, stacked), series: .value("Layer", "stacked"))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(color.opacity(0.2))
                    LineMark(x: .value("Time", sample.date), y: .value(label, sample.value + stacked), series: .value("Layer", "top"))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(color.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                }
                LineMark(x: .value("Time", sample.date), y: .value(label, sample.value), series: .value("Layer", "line"))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
            .metricAxes(time: ChartTimeAxis(dates: samples.map(\.date)), axisMax: axisMax, format: format)
        }
    }
}

struct NetworkSample: Identifiable {
    let date: Date
    let sent: Double
    let received: Double

    var id: Date { date }
}

struct NetworkChart: View {
    let samples: [NetworkSample]

    private var axisMax: Double {
        let peak = samples.map { max($0.sent, $0.received) }.max() ?? 0
        return max(1024, peak)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Network")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\u{2191} \(Self.rate(samples.last?.sent ?? 0))")
                    .foregroundColor(ChartPalette.sent)
                Text("\u{2193} \(Self.rate(samples.last?.received ?? 0))")
                    .foregroundColor(ChartPalette.received)
            }
            .font(.system(size: 10, weight: .semibold).monospacedDigit())

            Chart(samples) { sample in
                AreaMark(x: .value("Time", sample.date), y: .value("Sent", sample.sent), series: .value("Direction", "sent"), stacking: .unstacked)
                    .interpolationMethod(.monotone)
                    .foregroundStyle(ChartPalette.sent.opacity(0.25))
                AreaMark(x: .value("Time", sample.date), y: .value("Received", sample.received), series: .value("Direction", "received"), stacking: .unstacked)
                    .interpolationMethod(.monotone)
                    .foregroundStyle(ChartPalette.received.opacity(0.25))
                LineMark(x: .value("Time", sample.date), y: .value("Sent", sample.sent), series: .value("Direction", "sentLine"))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(ChartPalette.sent)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                LineMark(x: .value("Time", sample.date), y: .value("Received", sample.received), series: .value("Direction", "receivedLine"))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(ChartPalette.received)
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
            .metricAxes(time: ChartTimeAxis(dates: samples.map(\.date)), axisMax: axisMax, format: Self.rate)
        }
    }

    static func rate(_ bytesPerSecond: Double) -> String {
        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var value = bytesPerSecond
        var unit = 0
        while value >= 1024, unit < units.count - 1 {
            value /= 1024
            unit += 1
        }
        return unit == 0 ? String(format: "%.0f %@", value, units[unit]) : String(format: "%.1f %@", value, units[unit])
    }
}

struct MetricBar: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(value))%")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.primary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geometry.size.width * min(value / 100, 1.0), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}
