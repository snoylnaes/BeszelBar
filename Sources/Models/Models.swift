import Foundation

struct SystemRecord: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let status: String?
    let host: String?
    let port: String?
    let info: SystemInfo?
    let v: String?
    let updated: String?
}

struct SystemInfo: Codable, Hashable {
    let h: String?
    let k: String?
    let c: Int?
    let t: Int?
    let m: String?
    let o: String?
    let os: Int?
    let u: Double?
    let v: String?
    let cpu: Double?
    let mp: Double?
    let dp: Double?
    let b: Double?
    let bb: Double?
    let l1: Double?
    let l5: Double?
    let l15: Double?
    let la: [Double]?
    let bat: [Double]?
    let g: Double?
    let dt: Double?
    let p: Bool?
    let ct: Int?
    let efs: [String: Double]?
    let sv: [Int]?
    let rdn: String?
}

extension SystemRecord {
    var displayStatus: String {
        guard let status = status?.lowercased() else { return "Unknown" }
        switch status {
        case "up", "online": return "Online"
        case "down", "offline": return "Offline"
        case "pending": return "Pending"
        default: return status.capitalized
        }
    }

    var isOnline: Bool {
        guard let status = status?.lowercased() else { return false }
        return status == "up" || status == "online"
    }

    var cpuPercentage: Double? {
        info?.cpu
    }

    var memoryPercentage: Double? {
        info?.mp
    }

    var diskPercentage: Double? {
        info?.dp
    }

    var temperature: Double? {
        info?.dt
    }
}

struct SystemStatsRecord: Identifiable, Codable {
    let id: String
    let created: String
    let stats: SystemStatsDetail?
    let type: String?
}

struct SystemStatsDetail: Codable {
    let cpu: Double?
    let mp: Double?
    let dp: Double?
    let ns: Double?
    let nr: Double?
    let m: Double?
    let mu: Double?
    let mb: Double?
    let d: Double?
    let du: Double?
    let b: [Double]?
    let efs: [String: DiskStats]?
    let z: [String: DiskStats]?
    let ni: [String: [Double]]?

    enum CodingKeys: String, CodingKey {
        case cpu, mp, dp, ns, nr, m, mu, mb, d, du, b, efs, z, ni
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cpu = try container.decodeIfPresent(Double.self, forKey: .cpu)
        mp = try container.decodeIfPresent(Double.self, forKey: .mp)
        dp = try container.decodeIfPresent(Double.self, forKey: .dp)
        ns = try container.decodeIfPresent(Double.self, forKey: .ns)
        nr = try container.decodeIfPresent(Double.self, forKey: .nr)
        m = try container.decodeIfPresent(Double.self, forKey: .m)
        mu = try container.decodeIfPresent(Double.self, forKey: .mu)
        mb = try container.decodeIfPresent(Double.self, forKey: .mb)
        d = try container.decodeIfPresent(Double.self, forKey: .d)
        du = try container.decodeIfPresent(Double.self, forKey: .du)
        b = try? container.decodeIfPresent([Double].self, forKey: .b)
        efs = try? container.decodeIfPresent([String: DiskStats].self, forKey: .efs)
        z = try? container.decodeIfPresent([String: DiskStats].self, forKey: .z)
        ni = try? container.decodeIfPresent([String: [Double]].self, forKey: .ni)
    }
}

struct DiskStats: Codable {
    let n: String?
    let d: Double?
    let du: Double?
}

struct InterfaceSample {
    let sent: Double
    let received: Double
}

struct DiskSample {
    let name: String
    let total: Double
    let used: Double
}

struct StatPoint: Identifiable {
    let date: Date
    let cpu: Double?
    let mem: Double?
    let disk: Double?
    let memTotal: Double?
    let memUsed: Double?
    let memCache: Double?
    let diskTotal: Double?
    let diskUsed: Double?
    let netSent: Double?
    let netRecv: Double?
    let extraDisks: [String: DiskSample]
    let interfaces: [String: InterfaceSample]

    var id: Date { date }
}

extension SystemStatsRecord {
    var point: StatPoint? {
        guard let date = Self.parseCreated(created), let stats else { return nil }
        return StatPoint(
            date: date,
            cpu: stats.cpu,
            mem: stats.mp,
            disk: stats.dp,
            memTotal: stats.m,
            memUsed: stats.mu,
            memCache: stats.mb,
            diskTotal: stats.d,
            diskUsed: stats.du,
            netSent: stats.sentBytesPerSecond,
            netRecv: stats.receivedBytesPerSecond,
            extraDisks: stats.extraDisks,
            interfaces: stats.interfaces
        )
    }

    private static func parseCreated(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        for format in ["yyyy-MM-dd HH:mm:ss.SSS'Z'", "yyyy-MM-dd HH:mm:ss'Z'"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) { return date }
        }
        return nil
    }
}

extension SystemStatsDetail {
    private static let bytesPerMegabyte = 1_048_576.0

    var sentBytesPerSecond: Double? {
        if let b, b.count == 2 { return b[0] }
        return ns.map { $0 * Self.bytesPerMegabyte }
    }

    var interfaces: [String: InterfaceSample] {
        var samples: [String: InterfaceSample] = [:]
        for (name, values) in ni ?? [:] where values.count >= 2 {
            samples[name] = InterfaceSample(sent: values[0], received: values[1])
        }
        return samples
    }

    var extraDisks: [String: DiskSample] {
        var disks: [String: DiskSample] = [:]
        for (name, disk) in efs ?? [:] {
            if let total = disk.d, let used = disk.du {
                disks[ChartCatalog.efsID(name)] = DiskSample(name: name, total: total, used: used)
            }
        }
        for (key, disk) in z ?? [:] {
            if let total = disk.d, let used = disk.du {
                disks[ChartCatalog.poolID(key)] = DiskSample(name: disk.n ?? key, total: total, used: used)
            }
        }
        return disks
    }

    var receivedBytesPerSecond: Double? {
        if let b, b.count == 2 { return b[1] }
        return nr.map { $0 * Self.bytesPerMegabyte }
    }
}

struct SystemDetailsRecord: Identifiable, Codable, Hashable {
    let id: String
    let system: String
    let hostname: String?
    let kernel: String?
    let cores: Int?
    let threads: Int?
    let cpu: String?
    let memory: Int64?
    let os: Int?
    let osName: String?
    let arch: String?
    let podman: Bool?
    let updated: String?

    enum CodingKeys: String, CodingKey {
        case id, system, hostname, kernel, cores, threads, cpu, memory, os
        case osName = "os_name"
        case arch, podman, updated
    }
}

enum ContainerHealth: Int, Codable, Hashable {
    case none = 0
    case starting = 1
    case healthy = 2
    case unhealthy = 3

    var displayText: String {
        switch self {
        case .none: return "No Health Check"
        case .starting: return "Starting"
        case .healthy: return "Healthy"
        case .unhealthy: return "Unhealthy"
        }
    }

    var color: String {
        switch self {
        case .none: return "secondary"
        case .starting: return "orange"
        case .healthy: return "green"
        case .unhealthy: return "red"
        }
    }
}

struct ContainerRecord: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let cpu: Double
    let memory: Double
    let net: Double
    let health: ContainerHealth
    let status: String
    let image: String
    let system: String
    let updated: Int64

    var updatedDate: Date {
        Date(timeIntervalSince1970: Double(updated) / 1000.0)
    }
}

struct ContainerStatsRecord: Identifiable, Codable {
    let id: String
    let system: String
    let name: String?
    let cpu: Double?
    let mem: Double?
    let created: String?

    var containerID: String { id }
    var containerName: String? { name }
    var memory: Double? { mem }
}

struct AlertRecord: Identifiable, Codable {
    let id: String
    let name: String
    let system: String?
    let metric: String?
    let threshold: Double?
    let enabled: Bool?
    let triggered: Bool?
    let created: String?
    let updated: String?

    var displayMetric: String {
        metric ?? "unknown"
    }

    var displayThreshold: String {
        if let t = threshold {
            return String(format: "%.0f", t)
        }
        return "-"
    }
}

struct AlertHistoryRecord: Identifiable, Codable {
    let id: String
    let alert: String
    let system: String?
    let name: String?
    let message: String?
    let value: Double?
    let threshold: Double?
    let created: String?
}

struct PocketBaseListResponse<T: Codable>: Codable {
    let page: Int
    let perPage: Int
    let totalPages: Int
    let totalItems: Int
    let items: [T]
}

struct AuthResponse: Codable {
    let token: String
}

struct ChartOption: Identifiable, Hashable {
    let id: String
    let title: String
    let detectedTitle: String
    let subtitle: String
}

enum ChartCatalog {
    static let cpu = "cpu"
    static let memory = "memory"
    static let disk = "disk"
    static let network = "network"
    static let searchThreshold = 6
    static let defaultSelection = [cpu, memory, disk, network]

    private static let efsPrefix = "efs:"
    private static let poolPrefix = "z:"
    private static let interfacePrefix = "ni:"

    static func efsID(_ name: String) -> String { efsPrefix + name }
    static func poolID(_ key: String) -> String { poolPrefix + key }
    static func interfaceID(_ name: String) -> String { interfacePrefix + name }

    static func isInterface(_ id: String) -> Bool { id.hasPrefix(interfacePrefix) }
    static func interfaceName(_ id: String) -> String { String(id.dropFirst(interfacePrefix.count)) }

    static func kind(of id: String) -> String {
        if id.hasPrefix(poolPrefix) { return "Storage pool" }
        if id.hasPrefix(efsPrefix) { return "Extra filesystem" }
        if id.hasPrefix(interfacePrefix) { return "Network interface" }
        return "Chart"
    }

    static func fallbackTitle(_ id: String) -> String {
        for prefix in [efsPrefix, poolPrefix, interfacePrefix] where id.hasPrefix(prefix) {
            return String(id.dropFirst(prefix.count))
        }
        return id
    }
}

struct ChartSource {
    let options: [ChartOption]
    private let aliases: [String: String]

    init(system: SystemRecord?, history: [StatPoint], aliases: [String: String] = [:]) {
        self.aliases = aliases
        let latest = history.last
        let make = { (id: String, detected: String, subtitle: String) in
            Self.option(id, detected: detected, subtitle: subtitle, alias: aliases[id])
        }
        let builtIns = [
            make(ChartCatalog.cpu, "CPU", "Processor usage, percent"),
            make(ChartCatalog.memory, "Memory", "Used and cache, up to total RAM"),
            make(ChartCatalog.disk, system?.info?.rdn ?? "Root", "Root filesystem, used of total"),
            make(ChartCatalog.network, "Network", "All interfaces, sent and received")
        ]
        let disks = (latest?.extraDisks ?? [:]).map { id, disk in
            make(id, disk.name, "\(ChartCatalog.kind(of: id)), \(StorageFormat.size(disk.total))")
        }
        let interfaces = (latest?.interfaces ?? [:]).keys.map { name in
            let id = ChartCatalog.interfaceID(name)
            return make(id, name, ChartCatalog.kind(of: id))
        }
        options = builtIns + Self.sorted(disks) + Self.sorted(interfaces)
    }

    func option(for id: String) -> ChartOption {
        options.first { $0.id == id }
            ?? Self.option(
                id,
                detected: ChartCatalog.fallbackTitle(id),
                subtitle: "\(ChartCatalog.kind(of: id)), no recent data",
                alias: aliases[id]
            )
    }

    func title(for id: String) -> String {
        option(for: id).title
    }

    private static func option(_ id: String, detected: String, subtitle: String, alias: String?) -> ChartOption {
        ChartOption(
            id: id,
            title: alias ?? detected,
            detectedTitle: detected,
            subtitle: alias == nil ? subtitle : "\(detected) \u{00B7} \(subtitle)"
        )
    }

    private static func sorted(_ options: [ChartOption]) -> [ChartOption] {
        options.sorted { $0.detectedTitle.localizedStandardCompare($1.detectedTitle) == .orderedAscending }
    }
}
