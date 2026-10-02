import Foundation
import Observation

@Observable
@MainActor
final class AppState {
    static let shared = AppState()

    var instances: [Instance] = []
    var selectedInstance: Instance?
    var selectedInstanceSystems: [SystemRecord] = []
    var systemDetails: [String: SystemDetailsRecord] = [:]
    var containers: [String: [ContainerRecord]] = [:]
    var history: [String: [StatPoint]] = [:]
    /// When `history` last loaded, or nil when it has not loaded for this hub.
    var historyLoadedAt: Date?
    var activeAlerts: [AlertRecord] = []
    var isLoading: Bool { systemLoadsInProgress > 0 }
    private var systemLoadsInProgress = 0
    var errorMessage: String?
    var isConfigured = false
    var hiddenSystems: Set<String> = [] {
        didSet { storage.saveHiddenSystems(hiddenSystems) }
    }
    var defaultCharts: [String] = ChartCatalog.defaultSelection {
        didSet { storage.saveDefaultCharts(defaultCharts) }
    }
    var systemCharts: [String: [String]] = [:] {
        didSet { storage.saveSystemCharts(systemCharts) }
    }
    var chartTitles: [String: [String: String]] = [:] {
        didSet { storage.saveChartTitles(chartTitles) }
    }
    var systemOrder: [String] = [] {
        didSet { storage.saveSystemOrder(systemOrder) }
    }

    var visibleSystems: [SystemRecord] {
        selectedInstanceSystems.filter { !hiddenSystems.contains($0.id) }
    }

    static let menuSystemLimit = 15

    /// The visible systems that the menu has room to show.
    var menuSystems: [SystemRecord] {
        Array(visibleSystems.prefix(Self.menuSystemLimit))
    }

    private let storage = StorageManager()
    private let keychain = KeychainService.shared
    private var apiServices: [UUID: BeszelAPIService] = [:]
    private var detailsTask: Task<Void, Never>?
    private var alertTask: Task<Void, Never>?

    private init() {
        loadInstances()
        hiddenSystems = storage.loadHiddenSystems()
        defaultCharts = storage.loadDefaultCharts() ?? ChartCatalog.defaultSelection
        systemCharts = storage.loadSystemCharts()
        systemOrder = storage.loadSystemOrder()
        chartTitles = storage.loadChartTitles()
        isConfigured = !instances.isEmpty
        loadSystemDetails()
    }

    func loadSystems() async {
        guard let instance = selectedInstance else { return }

        systemLoadsInProgress += 1
        errorMessage = nil
        defer { systemLoadsInProgress -= 1 }

        do {
            let systems = try await getOrCreateService(for: instance).fetchSystems()
            guard selectedInstance?.id == instance.id else { return }
            selectedInstanceSystems = ordered(systems)
        } catch {
            guard selectedInstance?.id == instance.id else { return }
            errorMessage = error.localizedDescription
        }
    }

    /// Loads the history of each system in the menu.
    func loadHistory() async {
        guard let instance = selectedInstance else { return }

        let ids = menuSystems.map(\.id)
        let service = getOrCreateService(for: instance)
        var fetched: [String: [StatPoint]] = [:]
        await withTaskGroup(of: (String, [StatPoint]).self) { group in
            for id in ids {
                group.addTask {
                    let records = (try? await service.fetchSystemStats(systemID: id, limit: 60)) ?? []
                    return (id, records.compactMap(\.point).sorted { $0.date < $1.date })
                }
            }
            for await (id, points) in group where !points.isEmpty {
                fetched[id] = points
            }
        }
        guard selectedInstance?.id == instance.id, !fetched.isEmpty else { return }
        history.merge(fetched) { _, new in new }
        historyLoadedAt = .now
    }

    func moveSystems(fromOffsets source: IndexSet, toOffset destination: Int) {
        var ids = selectedInstanceSystems.map(\.id)
        ids.move(fromOffsets: source, toOffset: destination)
        systemOrder = ids + systemOrder.filter { !ids.contains($0) }
        selectedInstanceSystems = ordered(selectedInstanceSystems)
    }

    private func ordered(_ systems: [SystemRecord]) -> [SystemRecord] {
        let rank = Dictionary(systemOrder.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return systems.sorted { lhs, rhs in
            switch (rank[lhs.id], rank[rhs.id]) {
            case let (left?, right?): return left < right
            case (.some, nil): return true
            case (nil, .some): return false
            case (nil, nil): return lhs.name < rhs.name
            }
        }
    }

    func setTitle(_ title: String, chartID: String, systemID: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var titles = chartTitles[systemID] ?? [:]
        titles[chartID] = trimmed.isEmpty ? nil : trimmed
        let updated = titles.isEmpty ? nil : titles
        guard updated != chartTitles[systemID] else { return }
        chartTitles[systemID] = updated
    }

    /// The most recently fetched copy of `system`. Menu views use it so that a refresh updates the open menu.
    func latest(_ system: SystemRecord) -> SystemRecord {
        selectedInstanceSystems.first { $0.id == system.id } ?? system
    }

    func charts(for systemID: String) -> [String] {
        systemCharts[systemID] ?? defaultCharts
    }

    func setHidden(_ hidden: Bool, systemID: String) {
        if hidden {
            hiddenSystems.insert(systemID)
        } else {
            hiddenSystems.remove(systemID)
            Task { await loadHistory() }
        }
    }

    func loadSystemDetails() {
        guard let instance = selectedInstance else { return }

        detailsTask?.cancel()
        detailsTask = Task {
            do {
                let service = getOrCreateService(for: instance)
                let details = try await service.fetchSystemDetails()
                guard !Task.isCancelled else { return }

                var mapped: [String: SystemDetailsRecord] = [:]
                for detail in details {
                    mapped[detail.system] = detail
                }
                systemDetails = mapped
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
            }
        }
    }

    func loadAlerts() {
        guard let instance = selectedInstance else { return }

        alertTask?.cancel()
        alertTask = Task {
            do {
                let service = getOrCreateService(for: instance)
                let alerts = try await service.fetchAlerts(filter: "enabled = true")
                guard !Task.isCancelled else { return }
                activeAlerts = alerts.filter { $0.triggered == true }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
            }
        }
    }

    func loadContainers() async {
        guard let instance = selectedInstance else { return }

        let ids = menuSystems.map(\.id)
        guard !ids.isEmpty else {
            containers = [:]
            return
        }
        let filter = ids.map { "system = '\($0)'" }.joined(separator: " || ")
        guard let fetched = try? await getOrCreateService(for: instance).fetchContainers(filter: filter),
              selectedInstance?.id == instance.id else { return }
        containers = Dictionary(grouping: fetched, by: \.system)
    }

    func selectInstance(_ instance: Instance?) {
        selectedInstance = instance
        selectedInstanceSystems = []
        systemDetails = [:]
        containers = [:]
        history = [:]
        historyLoadedAt = nil
        activeAlerts = []
        storage.saveSelectedInstanceID(instance?.id)
        loadSystemDetails()
        RefreshService.shared.refresh()
    }

    func addInstance(_ instance: Instance) {
        keychain.saveCredential(instance.credential, for: instance.id.uuidString)

        var storedInstance = instance
        storedInstance.credential = ""
        instances.append(storedInstance)
        saveInstances()

        if selectedInstance == nil {
            selectInstance(instance)
        }
        isConfigured = true
    }

    func removeInstance(_ instance: Instance) {
        keychain.deleteCredential(for: instance.id.uuidString)
        apiServices.removeValue(forKey: instance.id)
        instances.removeAll { $0.id == instance.id }
        saveInstances()

        if selectedInstance?.id == instance.id {
            selectInstance(instances.first)
        }
        isConfigured = !instances.isEmpty
    }

    func updateInstance(_ instance: Instance) {
        if !instance.credential.isEmpty {
            keychain.updateCredential(instance.credential, for: instance.id.uuidString)
        }

        apiServices.removeValue(forKey: instance.id)

        if let index = instances.firstIndex(where: { $0.id == instance.id }) {
            var storedInstance = instance
            storedInstance.credential = ""
            instances[index] = storedInstance
            saveInstances()
        }

        if selectedInstance?.id == instance.id {
            selectInstance(instance)
        }
    }

    func instanceWithCredential(_ instance: Instance) -> Instance {
        var fullInstance = instance
        fullInstance.credential = keychain.loadCredential(for: instance.id.uuidString) ?? ""
        return fullInstance
    }

    private func loadInstances() {
        instances = storage.loadInstances()

        if let savedID = storage.loadSelectedInstanceID(),
           let instance = instances.first(where: { $0.id == savedID }) {
            selectedInstance = instance
        } else {
            selectedInstance = instances.first
        }
    }

    private func saveInstances() {
        storage.saveInstances(instances)
    }

    private func getOrCreateService(for instance: Instance) -> BeszelAPIService {
        if let existing = apiServices[instance.id] {
            return existing
        }

        let fullInstance = instanceWithCredential(instance)
        let service = BeszelAPIService(instance: fullInstance)
        apiServices[instance.id] = service
        return service
    }
}

struct Instance: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var url: String
    var email: String
    var credential: String

    init(id: UUID = UUID(), name: String, url: String, email: String, credential: String) {
        self.id = id
        self.name = name
        self.url = url
        self.email = email
        self.credential = credential
    }

    enum CodingKeys: String, CodingKey {
        case id, name, url, email
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        url = try container.decode(String.self, forKey: .url)
        email = try container.decode(String.self, forKey: .email)
        credential = ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(url, forKey: .url)
        try container.encode(email, forKey: .email)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Instance, rhs: Instance) -> Bool {
        lhs.id == rhs.id
    }
}

final class StorageManager {
    private let defaults = UserDefaults.standard
    private let instancesKey = "com.nohitdev.BeszelBar.instances"
    private let selectedInstanceKey = "com.nohitdev.BeszelBar.selectedInstance"

    func saveInstances(_ instances: [Instance]) {
        guard let data = try? JSONEncoder().encode(instances) else { return }
        defaults.set(data, forKey: instancesKey)
    }

    func loadInstances() -> [Instance] {
        guard let data = defaults.data(forKey: instancesKey),
              let instances = try? JSONDecoder().decode([Instance].self, from: data) else {
            return []
        }
        return instances
    }

    private let hiddenSystemsKey = "com.nohitdev.BeszelBar.hiddenSystems"
    private let defaultChartsKey = "com.nohitdev.BeszelBar.defaultCharts"
    private let systemChartsKey = "com.nohitdev.BeszelBar.systemCharts"
    private let systemOrderKey = "com.nohitdev.BeszelBar.systemOrder"
    private let chartTitlesKey = "com.nohitdev.BeszelBar.chartTitles"

    func saveChartTitles(_ titles: [String: [String: String]]) {
        defaults.set(titles, forKey: chartTitlesKey)
    }

    func loadChartTitles() -> [String: [String: String]] {
        defaults.dictionary(forKey: chartTitlesKey) as? [String: [String: String]] ?? [:]
    }

    func saveSystemOrder(_ ids: [String]) {
        defaults.set(ids, forKey: systemOrderKey)
    }

    func loadSystemOrder() -> [String] {
        defaults.stringArray(forKey: systemOrderKey) ?? []
    }

    func saveHiddenSystems(_ ids: Set<String>) {
        defaults.set(Array(ids), forKey: hiddenSystemsKey)
    }

    func loadHiddenSystems() -> Set<String> {
        Set(defaults.stringArray(forKey: hiddenSystemsKey) ?? [])
    }

    func saveDefaultCharts(_ ids: [String]) {
        defaults.set(ids, forKey: defaultChartsKey)
    }

    func loadDefaultCharts() -> [String]? {
        defaults.stringArray(forKey: defaultChartsKey)
    }

    func saveSystemCharts(_ charts: [String: [String]]) {
        defaults.set(charts, forKey: systemChartsKey)
    }

    func loadSystemCharts() -> [String: [String]] {
        defaults.dictionary(forKey: systemChartsKey) as? [String: [String]] ?? [:]
    }

    func saveSelectedInstanceID(_ id: UUID?) {
        if let id = id {
            defaults.set(id.uuidString, forKey: selectedInstanceKey)
        } else {
            defaults.removeObject(forKey: selectedInstanceKey)
        }
    }

    func loadSelectedInstanceID() -> UUID? {
        guard let string = defaults.string(forKey: selectedInstanceKey) else { return nil }
        return UUID(uuidString: string)
    }
}
