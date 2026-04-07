import SwiftUI
import AppKit

@main
struct ClaudeMenuApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    let viewModel = RateLimitsViewModel()

    private var statuslineBinaryPath: String {
        if let bundled = Bundle.main.path(forResource: "claude-statusline", ofType: nil) {
            return bundled
        }
        // Fallback for dev builds: sibling in same directory
        let exe = Bundle.main.executablePath ?? ""
        let dir = (exe as NSString).deletingLastPathComponent
        return (dir as NSString).appendingPathComponent("claude-statusline")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Kill any existing instance
        let dominated = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier!)
            .filter { $0 != NSRunningApplication.current }
        for app in dominated { app.terminate() }

        NSApp.setActivationPolicy(.accessory)

        ensureStatusLineConfigured()

        statusItem = NSStatusBar.system.statusItem(withLength: 64)

        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 200)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: RateLimitsView(viewModel: viewModel))

        viewModel.load()
        updateIcon()
        viewModel.onUpdate = { [weak self] in
            self?.updateIcon()
        }
    }

    // MARK: - Settings injection

    private let settingsPath = NSString(string: "~/.claude/settings.json").expandingTildeInPath

    private func ensureStatusLineConfigured() {
        // Read current settings
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: settingsPath)),
              let settings = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // No settings file or unparseable — ask to create statusLine entry
            promptToInject(existingCommand: nil)
            return
        }

        // Check if statusLine already points to our binary
        if let sl = settings["statusLine"] as? [String: Any],
           let cmd = sl["command"] as? String,
           cmd.contains("claude-statusline") {
            return // already configured
        }

        // There may be an existing statusLine command to wrap
        var existingCommand: String?
        if let sl = settings["statusLine"] as? [String: Any],
           let cmd = sl["command"] as? String {
            existingCommand = cmd
        }

        promptToInject(existingCommand: existingCommand)
    }

    private func promptToInject(existingCommand: String?) {
        let binaryPath = statuslineBinaryPath

        var message = "ClaudeMenu needs to configure Claude Code's statusLine to receive usage data."
        if let existing = existingCommand {
            message += "\n\nYour existing statusline command will be preserved:\n\(existing)"
        }

        let alert = NSAlert()
        alert.messageText = "Configure Claude Code StatusLine?"
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Configure")
        alert.addButton(withTitle: "Skip")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        writeStatusLineConfig(binaryPath: binaryPath, wrapCommand: existingCommand)
    }

    private func writeStatusLineConfig(binaryPath: String, wrapCommand: String?) {
        var command = binaryPath
        if let wrap = wrapCommand {
            // Escape the wrapped command for shell safety
            let escaped = wrap.replacingOccurrences(of: "'", with: "'\\''")
            command += " --wrap '\(escaped)'"
        }

        let url = URL(fileURLWithPath: settingsPath)

        var settings: [String: Any]
        if let data = try? Data(contentsOf: url),
           let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = parsed
        } else {
            settings = [:]
        }

        settings["statusLine"] = [
            "type": "command",
            "command": command
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys]),
           var jsonString = String(data: jsonData, encoding: .utf8) {
            // Ensure trailing newline
            if !jsonString.hasSuffix("\n") { jsonString += "\n" }
            try? jsonString.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func updateIcon() {
        guard let button = statusItem?.button else { return }
        let fh = viewModel.fiveHour ?? 0
        let wd = viewModel.sevenDay ?? 0
        let fhMarker = expectedUsage(resetsAt: viewModel.fiveHourReset, windowSeconds: fiveHourSeconds)
        let wdMarker = expectedUsage(resetsAt: viewModel.sevenDayReset, windowSeconds: sevenDaySeconds)
        let fhLevel = UsageLevel.classify(usage: fh, resetsAt: viewModel.fiveHourReset, windowSeconds: fiveHourSeconds)
        let wdLevel = UsageLevel.classify(usage: wd, resetsAt: viewModel.sevenDayReset, windowSeconds: sevenDaySeconds)
        let isDark = button.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        button.image = drawProgressBars(
            fiveHour: fh, sevenDay: wd,
            fhMarker: fhMarker, wdMarker: wdMarker,
            fhLevel: fhLevel, wdLevel: wdLevel,
            isDarkMenuBar: isDark
        )
        button.title = ""
    }

    func nsColor(for level: UsageLevel) -> NSColor {
        switch level {
        case .normal:   return NSColor(red: 0.3, green: 0.78, blue: 0.4, alpha: 1)
        case .warning:  return NSColor(red: 0.95, green: 0.6, blue: 0.1, alpha: 1)
        case .critical: return NSColor(red: 0.95, green: 0.25, blue: 0.2, alpha: 1)
        }
    }

    func drawProgressBars(fiveHour: Double, sevenDay: Double, fhMarker: Double, wdMarker: Double, fhLevel: UsageLevel, wdLevel: UsageLevel, isDarkMenuBar: Bool) -> NSImage {
        let barWidth: CGFloat = 30
        let height: CGFloat = 18
        let barHeight: CGFloat = 5
        let barGap: CGFloat = 3
        let cornerRadius: CGFloat = 2.0
        let borderWidth: CGFloat = 0.75
        let textGap: CGFloat = 3

        let font = NSFont.monospacedDigitSystemFont(ofSize: 8.5, weight: .medium)
        let menuBarTextColor = isDarkMenuBar ? NSColor.white : NSColor.black
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: menuBarTextColor.withAlphaComponent(0.85)
        ]

        let topText = NSAttributedString(string: String(format: "%.0f%%", fiveHour), attributes: textAttrs)
        let botText = NSAttributedString(string: String(format: "%.0f%%", sevenDay), attributes: textAttrs)
        let textWidth = max(topText.size().width, botText.size().width)
        let totalWidth = barWidth + textGap + textWidth

        let image = NSImage(size: NSSize(width: totalWidth, height: height), flipped: false) { rect in
            let totalHeight = barHeight * 2 + barGap
            let yOffset = (height - totalHeight) / 2
            let borderColor = menuBarTextColor.withAlphaComponent(0.45)
            let trackColor = NSColor.gray.withAlphaComponent(0.15)

            let markerColor = menuBarTextColor.withAlphaComponent(0.35)

            // Helper to draw one bar with marker
            func drawBar(y: CGFloat, usage: Double, marker: Double, level: UsageLevel, label: NSAttributedString) {
                // Track
                let trackRect = NSRect(x: 0, y: y, width: barWidth, height: barHeight)
                let track = NSBezierPath(roundedRect: trackRect, xRadius: cornerRadius, yRadius: cornerRadius)
                trackColor.setFill()
                track.fill()

                // Fill
                let fillWidth = max(0, barWidth * min(CGFloat(usage), 100) / 100)
                if fillWidth > 0 {
                    let fill = NSBezierPath(roundedRect: NSRect(x: 0, y: y, width: fillWidth, height: barHeight), xRadius: cornerRadius, yRadius: cornerRadius)
                    self.nsColor(for: level).setFill()
                    fill.fill()
                }

                // Time marker dotted line
                let markerX = barWidth * min(CGFloat(marker), 100) / 100
                if markerX > 0 && markerX < barWidth {
                    let dash = NSBezierPath()
                    dash.move(to: NSPoint(x: markerX, y: y))
                    dash.line(to: NSPoint(x: markerX, y: y + barHeight))
                    markerColor.setStroke()
                    dash.lineWidth = 1.0
                    dash.setLineDash([1.5, 1.0], count: 2, phase: 0)
                    dash.stroke()
                }

                // Border
                borderColor.setStroke()
                track.lineWidth = borderWidth
                track.stroke()

                // Text
                let textY = y + (barHeight - label.size().height) / 2
                label.draw(at: NSPoint(x: barWidth + textGap, y: textY))
            }

            let topY = yOffset + barHeight + barGap
            drawBar(y: topY, usage: fiveHour, marker: fhMarker, level: fhLevel, label: topText)

            let botY = yOffset
            drawBar(y: botY, usage: sevenDay, marker: wdMarker, level: wdLevel, label: botText)

            return true
        }

        image.isTemplate = false
        return image
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            viewModel.load()
            updateIcon()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
