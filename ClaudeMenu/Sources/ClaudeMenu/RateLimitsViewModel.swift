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

    private let filePath = "/tmp/claude-rate-limits.json"

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
}
