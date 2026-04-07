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
    if let jsonData = try? JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted, .sortedKeys]),
       let jsonString = String(data: jsonData, encoding: .utf8) {
        try? jsonString.write(toFile: "/tmp/claude-rate-limits.json", atomically: true, encoding: .utf8)
    }
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
