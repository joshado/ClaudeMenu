import SwiftUI

struct RateLimitsView: View {
    @ObservedObject var viewModel: RateLimitsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "sparkle")
                    .foregroundColor(.purple)
                Text("Claude Usage")
                    .font(.headline)
                Spacer()
                Button(action: { viewModel.load() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }

            if !viewModel.fileFound {
                noDataView
            } else {
                usageBar(
                    label: "Session (5h)",
                    percentage: viewModel.fiveHour,
                    resetDate: viewModel.fiveHourReset,
                    windowSeconds: fiveHourSeconds
                )
                usageBar(
                    label: "Weekly (7d)",
                    percentage: viewModel.sevenDay,
                    resetDate: viewModel.sevenDayReset,
                    windowSeconds: sevenDaySeconds
                )

                if let updated = viewModel.lastUpdated {
                    Text("Updated \(updated, style: .relative) ago")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            QuitMenuItemView()
        }
        .padding(16)
        .frame(width: 280)
    }

    private var noDataView: some View {
        VStack(spacing: 6) {
            Text("No usage data yet")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Start a Claude Code session to see limits.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func usageBar(label: String, percentage: Double?, resetDate: Date?, windowSeconds: TimeInterval) -> some View {
        let level = UsageLevel.classify(usage: percentage ?? 0, resetsAt: resetDate, windowSeconds: windowSeconds)
        let marker = expectedUsage(resetsAt: resetDate, windowSeconds: windowSeconds)

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if let pct = percentage {
                    Text(String(format: "%.1f%%", pct))
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundColor(swiftUIColor(for: level))
                } else {
                    Text("—")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 8)

                    if let pct = percentage {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(swiftUIColor(for: level))
                            .frame(width: max(0, geo.size.width * min(pct, 100) / 100), height: 8)
                            .animation(.easeInOut(duration: 0.3), value: pct)
                    }

                    // Time marker dotted line
                    let markerX = geo.size.width * min(marker, 100) / 100
                    if markerX > 0 && markerX < geo.size.width {
                        Path { path in
                            path.move(to: CGPoint(x: markerX, y: 0))
                            path.addLine(to: CGPoint(x: markerX, y: 8))
                        }
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [2, 1.5]))
                        .foregroundColor(.primary.opacity(0.35))
                        .frame(height: 8)
                    }
                }
            }
            .frame(height: 8)

            if let reset = resetDate {
                Text("Resets in \(formatDuration(until: reset))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func formatDuration(until date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSinceNow))
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func swiftUIColor(for level: UsageLevel) -> Color {
        switch level {
        case .normal:   return .green
        case .warning:  return .orange
        case .critical: return .red
        }
    }
}
