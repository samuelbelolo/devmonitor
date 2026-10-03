import AppKit
import DevMonitorUI
import SwiftUI

// Renders the menu bar window to a PNG from two real scans, to review the layout without opening the app.
let output = CommandLine.arguments.dropFirst().first ?? "snapshot.png"

/// Draws the menu window off screen from live data and writes it as a PNG.
/// @example await render(to: "snapshot.png")
@MainActor
func render(to path: String) async {
    let store = MonitorStore()
    try? await Task.sleep(for: .seconds(9))
    await store.refresh()
    // Sized the way MenuBarExtra sizes its window: from the content's preferred size, not its fitting size.
    let controller = NSHostingController(rootView: MenuContentView().environmentObject(store).background(Color(nsColor: .windowBackgroundColor)))
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
