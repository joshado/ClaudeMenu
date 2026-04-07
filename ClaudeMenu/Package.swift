// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeMenu",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClaudeMenu",
            path: "Sources/ClaudeMenu"
        ),
        .executableTarget(
            name: "claude-statusline",
            path: "Sources/claude-statusline"
        )
    ]
)
