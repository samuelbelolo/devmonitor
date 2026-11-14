import AppKit
import DevMonitorCore
import DevMonitorUI
import SwiftUI

// Renders a window of the app to a PNG from real scans, to review the layout without opening the app.
// Usage: devmon-snapshot out.png [memory|agents]
// Or renders every image of the documentation from a made-up Mac, in English:
// Usage: devmon-snapshot sample docs/media -AppleLanguages "(en)"
let arguments = Array(CommandLine.arguments.dropFirst())
let output = arguments.first ?? "snapshot.png"
let showsAgents = arguments.dropFirst().first == "agents"

/// Draws the chosen window off screen from live data and writes it as a PNG.
/// @example await render(to: "snapshot.png")
@MainActor
func render(to path: String) async {
    let store = MonitorStore()
    let versions = VersionStore()
    let extensions = ExtensionStore(versions: versions)
    // Two scans at least, so the working state of the agent sessions is known.
    try? await Task.sleep(for: .seconds(9))
    await store.refresh()
    await versions.refresh(fetchingLatest: true)
    // The store asked GitHub when it was created, during the wait above: this only reads the files again.
    await extensions.refresh(fetchingUpstream: false)
    let content: AnyView = showsAgents
        // The accounts are never read here: a second program renewing their sign-ins would end the app's.
        ? AnyView(AgentsContentView().agentEnvironment(store: store, versions: versions, extensions: extensions).environmentObject(UsageStore.placeholder()))
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

/// Writes every image of the documentation into a folder from the sample Mac; false when one could not be written.
/// @example await renderSamples(into: "docs/media") // true
@MainActor
func renderSamples(into folder: String) async -> Bool {
    try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
    var written = await WindowImage.write(SampleWindows.memory(), to: "\(folder)/memory-window.png")
    written = await WindowImage.write(SampleWindows.memory(swap: .critical), to: "\(folder)/memory-window-swap-critical.png") && written
    written = await WindowImage.write(SampleWindows.agents(), to: "\(folder)/agents-window.png") && written
    written = await WindowImage.write(SampleWindows.swapLines(), to: "\(folder)/swap-line-states.png") && written
    for (state, name) in [(SwapState.fine, "menu-bar"), (.high, "menu-bar-swap-high"), (.critical, "menu-bar-swap-critical")] {
        written = await WindowImage.write(SampleWindows.menuBar(swap: state), to: "\(folder)/\(name).png", cornerRadius: 8, margin: 14) && written
    }
    written = await WindowImage.write(SampleUsage.window(), to: "\(folder)/accounts-window.png") && written
    written = await WindowImage.write(SampleUsage.menuBar(), to: "\(folder)/menu-bar-accounts.png", cornerRadius: 8, margin: 14) && written
    written = await WindowImage.write(SampleUsage.resetConfirmation(), to: "\(folder)/accounts-reset.png") && written
    return written
}

Task { @MainActor in
    if arguments.first == "usage" {
        // The accounts window, from made-up accounts, for review only: `make media` does not publish it.
        // Variants: none (the window and its menu bar item), "confirm", "agents" (the entry closed), "entry" (opened),
        // "reset" (the confirmation of a reset and the notes of a spend).
        let path = arguments.dropFirst().first ?? "usage.png"
        // An option such as -AppleLanguages is not a variant.
        let variant = arguments.dropFirst(2).first.flatMap { $0.hasPrefix("-") ? nil : $0 }
        let view: AnyView = switch variant {
        case "confirm": AnyView(SampleUsage.window(confirming: true))
        case "agents": AnyView(SampleWindows.agents())
        case "entry": AnyView(SampleUsage.openEntry())
        case "reset": AnyView(SampleUsage.resetPanels())
        default: AnyView(SampleUsage.window())
        }
        var written = await WindowImage.write(view, to: path)
        if variant == nil {
            written = await WindowImage.write(SampleUsage.menuBar(), to: path.replacingOccurrences(of: ".png", with: "-menu-bar.png"), cornerRadius: 8, margin: 14) && written
        }
        exit(written ? 0 : 1)
    }
    if arguments.first == "sample" {
        // The images are published in English, whatever the language of the Mac that renders them.
        guard AppLanguage.current == .english else {
            FileHandle.standardError.write(Data("Run `make media`: it renders the images in English.\n".utf8))
            exit(1)
        }
        exit(await renderSamples(into: arguments.dropFirst().first ?? "docs/media") ? 0 : 1)
    }
    await render(to: output)
    exit(0)
}
NSApplication.shared.run()
