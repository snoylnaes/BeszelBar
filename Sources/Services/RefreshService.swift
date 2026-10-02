import Foundation
import Combine

@MainActor
final class RefreshService {
    static let shared = RefreshService()

    static let intervalKey = "refreshInterval"
    static let defaultInterval = 30

    private var timer: Timer?
    private var timerInterval: Int?
    private var isMenuOpen = false
    private var cancellables = Set<AnyCancellable>()

    private var refreshInterval: Int {
        UserDefaults.standard.integer(forKey: Self.intervalKey).clamped(to: 10...300)
    }

    private init() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.restartTimerIfIntervalChanged()
            }
            .store(in: &cancellables)
    }

    func restartTimer() {
        stop()

        let interval = refreshInterval
        timerInterval = interval
        let newTimer = Timer(timeInterval: TimeInterval(interval), repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        timerInterval = nil
    }

    private func restartTimerIfIntervalChanged() {
        guard let timerInterval, timerInterval != refreshInterval else { return }
        restartTimer()
    }

    /// Refreshes at once and restarts the timer, unless the history is newer than one interval.
    func menuWillOpen() {
        isMenuOpen = true
        if let loadedAt = AppState.shared.historyLoadedAt,
           Date.now.timeIntervalSince(loadedAt) < TimeInterval(refreshInterval) {
            return
        }
        restartTimer()
        refresh()
    }

    func menuDidClose() {
        isMenuOpen = false
    }

    /// History needs one request per system, so it loads only while the menu is open.
    func refresh() {
        let state = AppState.shared
        state.loadAlerts()
        Task {
            await state.loadSystems()
            state.loadContainers()
            if isMenuOpen {
                await state.loadHistory()
            }
        }
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
