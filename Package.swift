// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "DevMonitor",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "DevMonitorCore"),
        .target(name: "DevMonitorUI", dependencies: ["DevMonitorCore"]),
        .executableTarget(name: "DevMonitorApp", dependencies: ["DevMonitorCore", "DevMonitorUI"]),
        .executableTarget(name: "devmon-snapshot", dependencies: ["DevMonitorUI"]),
        .executableTarget(name: "devmon-dump", dependencies: ["DevMonitorCore"]),
        .testTarget(name: "DevMonitorCoreTests", dependencies: ["DevMonitorCore"]),
    ]
)
