import DevMonitorCore
import ServiceManagement
import SwiftUI

/// The window opened from the menu bar: total, projects, and the stop-idle action.
public struct MenuContentView: View {
    @EnvironmentObject private var store: MonitorStore
    @State private var launchesAtLogin = SMAppService.mainApp.status == .enabled

    /// The natural height of the project list; a ScrollView has none, so the window would collapse it to zero.
    @State private var listHeight: CGFloat = 0
    private static let maximumListHeight: CGFloat = 460
    /// The idle services counted when "Stop N idle" was first clicked: the second click stops exactly those.
    @State private var armedIdle: [Service] = []

    private var idleBytes: UInt64 { store.idleServices.reduce(0) { $0 + $1.memoryBytes } }

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(DisplayFormat.memory(store.totalBytes)).font(.system(size: 32, weight: .bold)).monospacedDigit()
                Text(Strings.usedBy(projects: store.groups.count)).foregroundStyle(.secondary)
                Spacer()
                settingsMenu
            }
            MemoryMeter(groups: store.groups, total: store.totalBytes)
            if store.groups.isEmpty {
                Text(Strings.nothingRunning).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(.vertical, 18)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(store.groups) { GroupSection(group: $0).id($0.id) }
                    }
                    .background(GeometryReader { Color.clear.preference(key: ListHeightKey.self, value: $0.size.height) })
                }
                .frame(height: min(max(listHeight, 40), Self.maximumListHeight))
                .onPreferenceChange(ListHeightKey.self) { listHeight = $0 }
            }
            if !store.idleServices.isEmpty {
                ConfirmButton(
                    title: Strings.stopIdle(count: store.idleServices.count, memory: DisplayFormat.memory(idleBytes)),
                    onArm: { armedIdle = store.idleServices },
                    action: { store.stop(armedIdle) })
                .frame(maxWidth: .infinity)
            }
        }
        .font(.system(size: 12.5))
        .padding(14)
        .frame(width: 400)
        .onAppear { store.setWindow(.memory, isOpen: true) }
        .onDisappear { store.setWindow(.memory, isOpen: false) }
    }

    private var settingsMenu: some View {
        Menu {
            Toggle(Strings.launchAtLogin, isOn: Binding(get: { launchesAtLogin }, set: setLaunchAtLogin))
            Divider()
            Button(Strings.quit) { NSApplication.shared.terminate(nil) }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    /// Registers or unregisters the app as a login item, and reflects what macOS accepted.
    /// @example setLaunchAtLogin(true)
    private func setLaunchAtLogin(_ enabled: Bool) {
        if enabled { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
        launchesAtLogin = SMAppService.mainApp.status == .enabled
    }
}
