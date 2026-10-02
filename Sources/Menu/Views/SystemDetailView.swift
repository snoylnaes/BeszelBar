import SwiftUI
import Charts

struct SystemDetailView: View {
    let system: SystemRecord
    var details: SystemDetailsRecord? = nil
    var charts: [String] = ChartCatalog.defaultSelection
    var titles: [String: String] = [:]
    var openInBrowser: () -> Void = {}
    var browserSymbol = "globe"

    private var cpuModel: String? {
        (details?.cpu ?? system.info?.m)?
            .replacingOccurrences(of: "(R)", with: "®", options: .caseInsensitive)
            .replacingOccurrences(of: "(TM)", with: "™", options: .caseInsensitive)
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
                    Text(hostname ?? system.name)
                        .lineLimit(1)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    PanelIconButton(systemName: browserSymbol, help: "Open in Browser", action: openInBrowser)
                }
                .zIndex(1)

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
            .chartCard()
            .zIndex(1)

            let history = AppState.shared.history[system.id] ?? []
            let source = ChartSource(system: system, history: history, aliases: titles)
            ForEach(charts, id: \.self) { chartID in
                chart(chartID, history: history, title: source.title(for: chartID))
                    .chartCard()
            }
        }
        .padding(.horizontal, ChartLayout.panelPadding)
        .padding(.vertical, ChartLayout.panelPadding)
        .frame(width: ChartLayout.panelWidth)
    }

    @ViewBuilder
    private func chart(_ chartID: String, history: [StatPoint], title: String) -> some View {
        let latest = history.last
        switch chartID {
        case ChartCatalog.cpu:
            MetricChart(
                label: title,
                percent: latest?.cpu ?? system.cpuPercentage,
                detail: nil,
                color: ChartPalette.cpu,
                samples: history.compactMap { point in
                    point.cpu.map { ChartSample(date: point.date, value: $0, stacked: nil) }
                },
                yMax: nil,
                format: { String(format: "%.0f%%", $0) },
                preciseFormat: { String(format: "%.2f%%", $0) }
            )
        case ChartCatalog.memory:
            MetricChart(
                label: title,
                percent: latest?.mem ?? system.memoryPercentage,
                detail: usageDetail(used: latest?.memUsed, total: latest?.memTotal),
                color: ChartPalette.memory,
                samples: history.compactMap { point in
                    point.memUsed.map { ChartSample(date: point.date, value: $0, stacked: point.memCache) }
                },
                yMax: latest?.memTotal,
                format: StorageFormat.axis,
                preciseFormat: StorageFormat.precise
            )
        case ChartCatalog.disk:
            MetricChart(
                label: title,
                percent: latest?.disk ?? system.diskPercentage,
                detail: usageDetail(used: latest?.diskUsed, total: latest?.diskTotal),
                color: ChartPalette.disk,
                samples: history.compactMap { point in
                    point.diskUsed.map { ChartSample(date: point.date, value: $0, stacked: nil) }
                },
                yMax: latest?.diskTotal,
                format: StorageFormat.axis,
                preciseFormat: StorageFormat.precise
            )
        case ChartCatalog.network:
            NetworkChart(
                title: title,
                samples: history.map {
                    NetworkSample(date: $0.date, sent: $0.netSent ?? 0, received: $0.netRecv ?? 0)
                }
            )
        case _ where ChartCatalog.isInterface(chartID):
            let name = ChartCatalog.interfaceName(chartID)
            NetworkChart(
                title: title,
                samples: history.map {
                    let rate = $0.interfaces[name]
                    return NetworkSample(date: $0.date, sent: rate?.sent ?? 0, received: rate?.received ?? 0)
                }
            )
        default:
            let disk = latest?.extraDisks[chartID]
            MetricChart(
                label: title,
                percent: disk.flatMap { $0.total > 0 ? $0.used / $0.total * 100 : nil },
                detail: usageDetail(used: disk?.used, total: disk?.total),
                color: ChartPalette.disk,
                samples: history.compactMap { point in
                    point.extraDisks[chartID].map { ChartSample(date: point.date, value: $0.used, stacked: nil) }
                },
                yMax: disk?.total,
                format: StorageFormat.axis,
                preciseFormat: StorageFormat.precise
            )
        }
    }

    private func usageDetail(used: Double?, total: Double?) -> String? {
        guard let used, let total else { return nil }
        return StorageFormat.usage(used: used, total: total)
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

    /// System status colours from Beszel (MIT License, Copyright (c) henrygd):
    /// green-500 from `internal/site/src/index.css`, and Tailwind's red-500 and yellow-500.
    static let up = Color(red: 0.24, green: 0.72, blue: 0.40)
    static let down = Color(red: 0.984, green: 0.173, blue: 0.212)
    static let pending = Color(red: 0.937, green: 0.694, blue: 0)

    static func level(_ value: Double) -> Color {
        if value >= 90 { return red }
        if value >= 70 { return orange }
        return green
    }
}

/// Chart colors and fill opacities from Beszel (MIT License, Copyright (c) henrygd),
/// `internal/site/src/index.css` and the chart definitions under `components/routes/system/charts`.
enum ChartPalette {
    static let chart1 = hsl(220, 70, 50)
    static let chart2 = hsl(160, 60, 45)
    static let chart3 = hsl(30, 80, 55)
    static let chart4 = hsl(280, 65, 60)
    static let chart5 = hsl(340, 75, 55)
    static let loadAverage = [hsl(271, 81, 60), hsl(217, 91, 60), hsl(25, 95, 53)]

    static let cpu = chart1
    static let memory = chart2
    static let disk = chart4
    static let diskRead = chart1
    static let diskWrite = chart3
    static let sent = chart5
    static let received = chart2

    static let usageFill = 0.4
    static let ioFill = 0.3
    static let networkFill = 0.2
    static let cacheStrength = 0.5

    static func series(_ index: Int, of count: Int) -> Color {
        let hue = Double(index) * 360 / Double(max(1, count))
        return Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return nsColor(hue, isDark ? 60 : 65, isDark ? 55 : 50)
        })
    }

    static func hsl(_ hue: Double, _ saturation: Double, _ lightness: Double) -> Color {
        Color(nsColor: nsColor(hue, saturation, lightness))
    }

    private static func nsColor(_ hue: Double, _ saturation: Double, _ lightness: Double) -> NSColor {
        let s = saturation / 100
        let l = lightness / 100
        let chroma = (1 - abs(2 * l - 1)) * s
        let h = hue.truncatingRemainder(dividingBy: 360) / 60
        let x = chroma * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
        let (r, g, b): (Double, Double, Double)
        switch h {
        case ..<1: (r, g, b) = (chroma, x, 0)
        case ..<2: (r, g, b) = (x, chroma, 0)
        case ..<3: (r, g, b) = (0, chroma, x)
        case ..<4: (r, g, b) = (0, x, chroma)
        case ..<5: (r, g, b) = (x, 0, chroma)
        default: (r, g, b) = (chroma, 0, x)
        }
        let m = l - chroma / 2
        return NSColor(srgbRed: r + m, green: g + m, blue: b + m, alpha: 1)
    }
}

enum UnitFormat {
    private static let step = 1024.0
    private static let nextUnitAt = 999.5
    private static let decimalsBelow = 9.95

    static func compact(_ value: Double, units: [String]) -> String {
        var value = value
        var unit = 0
        while value >= nextUnitAt, unit < units.count - 1 {
            value /= step
            unit += 1
        }
        var number = String(format: value < decimalsBelow ? "%.1f" : "%.0f", value)
        if number.hasSuffix(".0") {
            number.removeLast(2)
        }
        return "\(number) \(units[unit])"
    }

    static func precise(_ value: Double, units: [String]) -> String {
        var value = value
        var unit = 0
        while value >= step, unit < units.count - 1 {
            value /= step
            unit += 1
        }
        return String(format: "%.2f %@", value, units[unit])
    }
}

enum StorageFormat {
    private static let gigabytesPerTerabyte = 1024.0
    private static let units = ["GB", "TB", "PB"]

    static func axis(_ gigabytes: Double) -> String {
        UnitFormat.compact(gigabytes, units: units)
    }

    static func precise(_ gigabytes: Double) -> String {
        UnitFormat.precise(gigabytes, units: units)
    }

    static func size(_ gigabytes: Double) -> String {
        if gigabytes >= gigabytesPerTerabyte {
            return String(format: "%.1f TB", gigabytes / gigabytesPerTerabyte)
        }
        return String(format: "%.0f GB", gigabytes)
    }

    static func usage(used: Double, total: Double) -> String {
        if total >= gigabytesPerTerabyte {
            return String(format: "%.1f / %.1f TB", used / gigabytesPerTerabyte, total / gigabytesPerTerabyte)
        }
        return String(format: "%.1f / %.1f GB", used, total)
    }
}

enum ChartLayout {
    static let panelWidth: CGFloat = 310
    static let panelPadding: CGFloat = 8
    static let axisFontSize: CGFloat = 8
    static let yLabelGap: CGFloat = 4
    static let cardPadding: CGFloat = 10
    static let cardCornerRadius: CGFloat = 10
    static let chartHeight: CGFloat = 80
    static let readoutGap: CGFloat = 8
    static let markerSize: CGFloat = 6
    static let contentWidth = panelWidth - 2 * panelPadding - 2 * cardPadding

    static func yLabelWidth(_ labels: [String]) -> CGFloat {
        let font = NSFont.systemFont(ofSize: axisFontSize)
        let widest = labels.map { NSAttributedString(string: $0, attributes: [.font: font]).size().width }.max() ?? 0
        return widest.rounded(.up)
    }
}

extension View {
    func chartCard() -> some View {
        self
            .padding(ChartLayout.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: ChartLayout.cardCornerRadius, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ChartLayout.cardCornerRadius, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            )
    }
}

/// Icon button for the hover panel. AppKit does not show tooltips while a menu is open, so the button draws its own.
struct PanelIconButton: View {
    let systemName: String
    let help: String
    /// Shows the tooltip to the left of the icon instead of below it, for rows too short to hold it below.
    var tooltipBeside = false
    let action: () -> Void

    @State private var isHovered = false
    @State private var showsTooltip = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 20, height: 20)
                .background {
                    if isHovered {
                        RoundedRectangle(cornerRadius: SystemMenuRowView.highlightCornerRadius, style: .continuous)
                            .fill(Color.primary.opacity(SystemMenuRowView.highlightOpacity))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: tooltipBeside ? .trailing : .topTrailing) {
            if showsTooltip {
                Text(help)
                    .font(.system(size: 10))
                    .fixedSize()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color(nsColor: .windowBackgroundColor))
                            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                    )
                    .offset(x: tooltipBeside ? -24 : 0, y: tooltipBeside ? 0 : 24)
                    .allowsHitTesting(false)
            }
        }
        .onHover { isHovered = $0 }
        .task(id: isHovered) {
            showsTooltip = false
            guard isHovered else { return }
            try? await Task.sleep(for: .milliseconds(600))
            if !Task.isCancelled { showsTooltip = true }
        }
    }
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

    func labelShift(for date: Date, plotWidth: CGFloat) -> CGFloat {
        let span = range.upperBound.timeIntervalSince(range.lowerBound)
        let halfLabel: CGFloat = 19
        let fromLeft = CGFloat(date.timeIntervalSince(range.lowerBound) / span) * plotWidth
        let fromRight = plotWidth - fromLeft
        if fromLeft < halfLabel { return halfLabel - fromLeft }
        if fromRight < halfLabel { return fromRight - halfLabel }
        return 0
    }
}

extension View {
    func metricAxes(time: ChartTimeAxis, axisMax: Double, format: @escaping (Double) -> String) -> some View {
        let values = [0, axisMax / 2, axisMax]
        let labelWidth = ChartLayout.yLabelWidth(values.map(format))
        let plotWidth = ChartLayout.contentWidth - labelWidth - ChartLayout.yLabelGap
        return self
            .chartXScale(domain: time.range)
            .chartYScale(domain: 0...axisMax)
            .chartYAxis {
                AxisMarks(position: .leading, values: values) { value in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.2))
                    AxisValueLabel {
                        if let number = value.as(Double.self) {
                            Text(format(number))
                                .font(.system(size: ChartLayout.axisFontSize))
                                .lineLimit(1)
                                .frame(width: labelWidth, alignment: .trailing)
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
                                .offset(x: time.labelShift(for: date, plotWidth: plotWidth), y: -2)
                        }
                    }
                }
            }
            .frame(height: ChartLayout.chartHeight)
    }
}

struct MetricChart: View {
    let label: String
    let percent: Double?
    let detail: String?
    let color: Color
    let samples: [ChartSample]
    let yMax: Double?
    let format: (Double) -> String
    let preciseFormat: (Double) -> String
    @State private var hoverX: CGFloat?

    private var axisMax: Double {
        if let yMax, yMax > 0 { return yMax }
        let peak = samples.map { $0.value + ($0.stacked ?? 0) }.max() ?? 0
        return max(10, peak.rounded(.up))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(percent.map { "\(Int($0))%" } ?? "\u{2013}")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundColor(percent.map { $0 >= 70 ? AppColors.level($0) : .primary } ?? .secondary)
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
                    .foregroundStyle(color.opacity(ChartPalette.usageFill))
                if let stacked = sample.stacked {
                    AreaMark(x: .value("Time", sample.date), y: .value(label, stacked), series: .value("Layer", "stacked"))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(color.opacity(ChartPalette.cacheStrength * ChartPalette.usageFill))
                    LineMark(x: .value("Time", sample.date), y: .value(label, sample.value + stacked), series: .value("Layer", "top"))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(color.opacity(ChartPalette.cacheStrength))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                }
                LineMark(x: .value("Time", sample.date), y: .value(label, sample.value), series: .value("Layer", "line"))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
            .chartOverlay { proxy in
                ChartHoverLayer(proxy: proxy, dates: samples.map(\.date), hoverX: $hoverX) { index in
                    let sample = samples[index]
                    if let stacked = sample.stacked {
                        return [
                            ReadoutItem(color: color, name: "Used", value: preciseFormat(sample.value), markerY: sample.value),
                            ReadoutItem(color: color.opacity(ChartPalette.cacheStrength), name: "Cache", value: preciseFormat(stacked), markerY: sample.value + stacked)
                        ]
                    }
                    return [ReadoutItem(color: color, name: label, value: preciseFormat(sample.value), markerY: sample.value)]
                }
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
    let title: String
    let samples: [NetworkSample]
    @State private var hoverX: CGFloat?

    private var axisMax: Double {
        let peak = samples.map { max($0.sent, $0.received) }.max() ?? 0
        return max(1024, peak)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                    .foregroundColor(.primary)
                Group {
                    Text("\u{2191} \(Self.rate(samples.last?.sent ?? 0))")
                        .foregroundColor(ChartPalette.sent)
                    Text("\u{2193} \(Self.rate(samples.last?.received ?? 0))")
                        .foregroundColor(ChartPalette.received)
                }
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                Spacer()
            }

            Chart(samples) { sample in
                AreaMark(x: .value("Time", sample.date), y: .value("Sent", sample.sent), series: .value("Direction", "sent"), stacking: .unstacked)
                    .interpolationMethod(.monotone)
                    .foregroundStyle(ChartPalette.sent.opacity(ChartPalette.networkFill))
                AreaMark(x: .value("Time", sample.date), y: .value("Received", sample.received), series: .value("Direction", "received"), stacking: .unstacked)
                    .interpolationMethod(.monotone)
                    .foregroundStyle(ChartPalette.received.opacity(ChartPalette.networkFill))
                LineMark(x: .value("Time", sample.date), y: .value("Sent", sample.sent), series: .value("Direction", "sentLine"))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(ChartPalette.sent)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                LineMark(x: .value("Time", sample.date), y: .value("Received", sample.received), series: .value("Direction", "receivedLine"))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(ChartPalette.received)
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
            .chartOverlay { proxy in
                ChartHoverLayer(proxy: proxy, dates: samples.map(\.date), hoverX: $hoverX) { index in
                    let sample = samples[index]
                    return [
                        ReadoutItem(color: ChartPalette.sent, name: "Sent", value: Self.preciseRate(sample.sent), markerY: sample.sent),
                        ReadoutItem(color: ChartPalette.received, name: "Received", value: Self.preciseRate(sample.received), markerY: sample.received)
                    ]
                }
            }
            .metricAxes(time: ChartTimeAxis(dates: samples.map(\.date)), axisMax: axisMax, format: Self.rate)
        }
    }

    private static let rateUnits = ["B/s", "KB/s", "MB/s", "GB/s"]

    static func rate(_ bytesPerSecond: Double) -> String {
        UnitFormat.compact(bytesPerSecond, units: rateUnits)
    }

    static func preciseRate(_ bytesPerSecond: Double) -> String {
        UnitFormat.precise(bytesPerSecond, units: rateUnits)
    }
}

struct ReadoutItem: Identifiable {
    let color: Color
    let name: String
    let value: String
    let markerY: Double

    var id: String { name }
}

struct ChartHoverLayer: View {
    let proxy: ChartProxy
    let dates: [Date]
    @Binding var hoverX: CGFloat?
    let items: (Int) -> [ReadoutItem]

    var body: some View {
        GeometryReader { geometry in
            if let plotFrame = proxy.plotFrame {
                let plot = geometry[plotFrame]
                ZStack(alignment: .topLeading) {
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let location) where plot.minX...plot.maxX ~= location.x:
                                hoverX = location.x - plot.minX
                            default:
                                hoverX = nil
                            }
                        }
                    if let index = nearestIndex(), let lineX = proxy.position(forX: dates[index]) {
                        let readoutItems = items(index)
                        Group {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.35))
                                .frame(width: 1, height: plot.height)
                                .offset(x: plot.minX + lineX, y: plot.minY)
                            ForEach(readoutItems) { item in
                                if let markerY = proxy.position(forY: item.markerY) {
                                    Circle()
                                        .fill(item.color)
                                        .frame(width: ChartLayout.markerSize, height: ChartLayout.markerSize)
                                        .offset(
                                            x: plot.minX + lineX - ChartLayout.markerSize / 2,
                                            y: plot.minY + markerY - ChartLayout.markerSize / 2
                                        )
                                }
                            }
                            if lineX > plot.width / 2 {
                                ChartReadout(date: dates[index], items: readoutItems)
                                    .frame(width: max(0, plot.minX + lineX - ChartLayout.readoutGap), alignment: .trailing)
                                    .offset(y: plot.minY)
                            } else {
                                ChartReadout(date: dates[index], items: readoutItems)
                                    .offset(x: plot.minX + lineX + ChartLayout.readoutGap, y: plot.minY)
                            }
                        }
                        .allowsHitTesting(false)
                    }
                }
            }
        }
    }

    private func nearestIndex() -> Int? {
        guard let hoverX, let date: Date = proxy.value(atX: hoverX) else { return nil }
        return dates.indices.min { abs(dates[$0].timeIntervalSince(date)) < abs(dates[$1].timeIntervalSince(date)) }
    }
}

struct ChartReadout: View {
    let date: Date
    let items: [ReadoutItem]

    private static let fontSize: CGFloat = 9
    private static let cornerRadius: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(date, format: .dateTime.hour().minute())
                .font(.system(size: Self.fontSize, weight: .medium))
                .foregroundColor(.primary)
            Grid(alignment: .leading, horizontalSpacing: 4, verticalSpacing: 1) {
                ForEach(items) { item in
                    GridRow {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(item.color)
                            .frame(width: 3, height: 8)
                        Text(item.name)
                            .foregroundColor(.secondary)
                        Text(item.value)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .gridColumnAlignment(.trailing)
                            .padding(.leading, 2)
                    }
                }
            }
            .font(.system(size: Self.fontSize).monospacedDigit())
        }
        .fixedSize()
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
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
