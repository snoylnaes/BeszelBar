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

    enum CodingKeys: String, CodingKey {
        case cpu, mp, dp, ns, nr, m, mu, mb, d, du, b
    }
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
            netRecv: stats.receivedBytesPerSecond
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
