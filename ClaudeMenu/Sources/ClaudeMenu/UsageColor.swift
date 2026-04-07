import Foundation

/// Calculates how far through a time window we are (0.0 to 1.0).
/// windowDuration: total window length in seconds (5h or 7d).
/// resetsAt: when the window resets.
func timeProgress(resetsAt: Date?, windowSeconds: TimeInterval) -> Double {
    guard let reset = resetsAt else { return 0 }
    let windowStart = reset.addingTimeInterval(-windowSeconds)
    let elapsed = Date().timeIntervalSince(windowStart)
    return min(max(elapsed / windowSeconds, 0), 1)
}

/// Returns the time-proportional expected usage percentage (0-100).
func expectedUsage(resetsAt: Date?, windowSeconds: TimeInterval) -> Double {
    timeProgress(resetsAt: resetsAt, windowSeconds: windowSeconds) * 100
}

enum UsageLevel {
    case normal  // at or below time marker
    case warning // above time marker
    case critical // consumed more than half of remaining budget past marker

    static func classify(usage: Double, resetsAt: Date?, windowSeconds: TimeInterval) -> UsageLevel {
        let marker = expectedUsage(resetsAt: resetsAt, windowSeconds: windowSeconds)
        if usage <= marker { return .normal }
        let remaining = 100 - marker
        let redThreshold = marker + remaining / 2
        if usage > redThreshold { return .critical }
        return .warning
    }
}

let fiveHourSeconds: TimeInterval = 5 * 3600
let sevenDaySeconds: TimeInterval = 7 * 24 * 3600
