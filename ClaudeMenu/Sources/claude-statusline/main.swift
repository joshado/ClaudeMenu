import Foundation

// Read all of stdin
let inputData = FileHandle.standardInput.readDataToEndOfFile()
let inputString = String(data: inputData, encoding: .utf8) ?? ""

// Parse rate limits and write to temp file
struct StatusLineInput: Codable {
    struct RateLimits: Codable {
        struct Window: Codable {
            let used_percentage: Double?
            let resets_at: Int?
        }
        let five_hour: Window?
        let seven_day: Window?
    }
    let rate_limits: RateLimits?
}

// Throttle state: tracks when we last wrote the cache file and sent a notification
let stateFilePath = "/tmp/claude-rate-limits.state"
let fileWriteInterval: TimeInterval = 15
let notifyInterval: TimeInterval = 1

struct ThrottleState {
    var lastFileWrite: TimeInterval = 0
    var lastNotify: TimeInterval = 0
}

func loadThrottleState() -> ThrottleState {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: stateFilePath)),
          let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Double] else {
        return ThrottleState()
    }
    return ThrottleState(
        lastFileWrite: dict["lastFileWrite"] ?? 0,
        lastNotify: dict["lastNotify"] ?? 0
    )
}

func saveThrottleState(_ state: ThrottleState) {
    let dict: [String: Double] = [
        "lastFileWrite": state.lastFileWrite,
        "lastNotify": state.lastNotify
    ]
    if let data = try? JSONSerialization.data(withJSONObject: dict) {
        try? data.write(to: URL(fileURLWithPath: stateFilePath))
    }
}

if let parsed = try? JSONDecoder().decode(StatusLineInput.self, from: inputData),
   let limits = parsed.rate_limits {
    let output: [String: Any] = [
        "five_hour": [
            "used_percentage": limits.five_hour?.used_percentage as Any,
            "resets_at": limits.five_hour?.resets_at as Any
        ],
        "seven_day": [
            "used_percentage": limits.seven_day?.used_percentage as Any,
            "resets_at": limits.seven_day?.resets_at as Any
        ],
        "updated_at": Int(Date().timeIntervalSince1970)
    ]

    let now = Date().timeIntervalSince1970
    var state = loadThrottleState()

    // Write cache file at most every 15 seconds
    if now - state.lastFileWrite >= fileWriteInterval {
        if let jsonData = try? JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            try? jsonString.write(toFile: "/tmp/claude-rate-limits.json", atomically: true, encoding: .utf8)
        }
        state.lastFileWrite = now
    }

    // Send IPC notification at most every 1 second
    if now - state.lastNotify >= notifyInterval {
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("org.haggett.claudemenu.rateLimitsUpdated"),
            object: nil,
            userInfo: output as [AnyHashable: Any],
            deliverImmediately: true
        )
        state.lastNotify = now
    }

    saveThrottleState(state)
}

// Check for --wrap argument to chain another statusline command
var wrapCommand: String?
let args = CommandLine.arguments
if let idx = args.firstIndex(of: "--wrap"), idx + 1 < args.count {
    wrapCommand = args[idx + 1]
}

if let wrap = wrapCommand {
    // Pipe the original input to the wrapped command and forward its output
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", wrap]

    let stdinPipe = Pipe()
    process.standardInput = stdinPipe
    let stdoutPipe = Pipe()
    process.standardOutput = stdoutPipe

    do {
        try process.run()
        stdinPipe.fileHandleForWriting.write(inputData)
        stdinPipe.fileHandleForWriting.closeFile()
        process.waitUntilExit()

        let wrappedOutput = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        if let out = String(data: wrappedOutput, encoding: .utf8) {
            print(out, terminator: "")
        }
    } catch {
        // Wrapped command failed; fall through to default output
    }
} else {
    // Default: print a compact summary
    if let parsed = try? JSONDecoder().decode(StatusLineInput.self, from: inputData),
       let limits = parsed.rate_limits {
        var parts: [String] = []
        if let fh = limits.five_hour?.used_percentage {
            parts.append("5h: \(Int(fh))%")
        }
        if let wd = limits.seven_day?.used_percentage {
            parts.append("7d: \(Int(wd))%")
        }
        if !parts.isEmpty {
            print(parts.joined(separator: " | "))
        }
    }
}
