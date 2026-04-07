import Foundation

struct RateLimitsData: Codable {
    struct Window: Codable {
        let used_percentage: Double?
        let resets_at: Int?
    }
    let five_hour: Window
    let seven_day: Window
    let updated_at: Int?
}

class RateLimitsViewModel: ObservableObject {
    @Published var fiveHour: Double?
    @Published var sevenDay: Double?
    @Published var fiveHourReset: Date?
    @Published var sevenDayReset: Date?
    @Published var lastUpdated: Date?
    @Published var fileFound = false

    static let notificationName = Notification.Name("org.haggett.claudemenu.rateLimitsUpdated")
    private let filePath = "/tmp/claude-rate-limits.json"
    var onUpdate: (() -> Void)?

    init() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleNotification(_:)),
            name: Self.notificationName,
            object: nil
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func handleNotification(_ notification: Notification) {
        guard let info = notification.userInfo else { return }
        applyUpdate(info)
        onUpdate?()
    }

    /// Load cached data from the JSON file on disk.
    func load() {
        let url = URL(fileURLWithPath: filePath)
        guard let data = try? Data(contentsOf: url),
              let parsed = try? JSONDecoder().decode(RateLimitsData.self, from: data) else {
            fileFound = false
            return
        }

        fileFound = true
        fiveHour = parsed.five_hour.used_percentage
        sevenDay = parsed.seven_day.used_percentage
        fiveHourReset = parsed.five_hour.resets_at.map { Date(timeIntervalSince1970: Double($0)) }
        sevenDayReset = parsed.seven_day.resets_at.map { Date(timeIntervalSince1970: Double($0)) }
        lastUpdated = parsed.updated_at.map { Date(timeIntervalSince1970: Double($0)) }
    }

    /// Apply an update received via IPC notification.
    private func applyUpdate(_ info: [AnyHashable: Any]) {
        fileFound = true
        if let fh = info["five_hour"] as? [String: Any] {
            fiveHour = fh["used_percentage"] as? Double
            fiveHourReset = (fh["resets_at"] as? Int).map { Date(timeIntervalSince1970: Double($0)) }
        }
        if let wd = info["seven_day"] as? [String: Any] {
            sevenDay = wd["used_percentage"] as? Double
            sevenDayReset = (wd["resets_at"] as? Int).map { Date(timeIntervalSince1970: Double($0)) }
        }
        lastUpdated = (info["updated_at"] as? Int).map { Date(timeIntervalSince1970: Double($0)) }
    }
}
