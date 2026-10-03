import Foundation

/// Ticks the frames of the working agents' logo, once a second and only while a session works. Each tick makes
/// macOS redraw the item on every screen (about 30 ms), hence the slow pace and the setting to turn it off.
@MainActor
public final class GlyphClock: ObservableObject {
    @Published private(set) var frame = 0
    /// Whether the logo turns while a session works; remembered, and on by default.
    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            update(hasWork: wantsToRun)
        }
    }

    private static let enabledKey = "animatesAgentLogo"
    private var timer: Timer?
    private var wantsToRun = false

    init() {
        isEnabled = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    /// Starts the ticks while a session works and the animation is on, and stops them otherwise.
    /// @example clock.update(hasWork: true)
    func update(hasWork: Bool) {
        wantsToRun = hasWork
        let isRunning = hasWork && isEnabled
        guard isRunning != (timer != nil) else { return }
        timer?.invalidate()
        timer = isRunning ? Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.frame += 1 }
        } : nil
        if !isRunning { frame = 0 }
    }
}
