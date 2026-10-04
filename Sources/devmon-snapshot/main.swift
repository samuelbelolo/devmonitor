import AppKit
import DevMonitorUI
import SwiftUI

// Renders a window of the app to a PNG from real scans, to review the layout without opening the app.
// Usage: devmon-snapshot out.png [memory|agents]
let arguments = Array(CommandLine.arguments.dropFirst())
let output = arguments.first ?? "snapshot.png"
let showsAgents = arguments.dropFirst().first == "agents"

/// Draws the chosen window off screen from live data and writes it as a PNG.
/// @example await render(to: "snapshot.png")
@MainActor
func render(to path: String) async {
    let store = MonitorStore()
    let versions = VersionStore()
    // Two scans at least, so the working state of the agent sessions is known.
    try? await Task.sleep(for: .seconds(9))
    await store.refresh()
    await versions.refresh(fetchingLatest: true)
    let content: AnyView = showsAgents
        ? AnyView(AgentsContentView().agentEnvironment(store: store, versions: versions))
        : AnyView(MenuContentView().environmentObject(store))
    // Sized the way MenuBarExtra sizes its window: from the content's preferred size, not its fitting size.
    let controller = NSHostingController(rootView: content.background(Color(nsColor: .windowBackgroundColor)))
    controller.sizingOptions = [.preferredContentSize]
    let window = NSWindow(contentViewController: controller)
    window.styleMask = [.borderless]
    window.orderFrontRegardless()
    let host = controller.view
    host.layoutSubtreeIfNeeded()
    try? await Task.sleep(for: .seconds(1))
    guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
    host.cacheDisplay(in: host.bounds, to: bitmap)
    try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
}

Task { @MainActor in
    await render(to: output)
    exit(0)
}
NSApplication.shared.run()
