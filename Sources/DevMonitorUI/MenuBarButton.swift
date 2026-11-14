import AppKit

/// Finds and presses the app's own menu bar buttons. A menu bar window closes as soon as another app is clicked, such
/// as the browser where a sign-in is allowed: the button that opened it is kept, to open it again on the way back.
@MainActor
enum MenuBarButton {
    /// Returns the app's menu bar button whose window is open, the highlighted one; nil when none is.
    /// @example MenuBarButton.open() // the accounts item's button, while its window shows
    static func open() -> NSStatusBarButton? {
        NSApp.windows.lazy.compactMap { $0.contentView.flatMap(button(in:)) }.first { $0.isHighlighted || $0.state == .on }
    }

    /// Opens a button's window again, unless it is already open.
    /// @example MenuBarButton.reopen(button)
    static func reopen(_ button: NSStatusBarButton) {
        guard !button.isHighlighted, button.state != .on, button.window != nil else { return }
        NSApp.activate()
        button.performClick(nil)
    }

    /// Returns the menu bar button inside a view, if there is one.
    /// @example button(in: window.contentView!) // an NSStatusBarButton
    private static func button(in view: NSView) -> NSStatusBarButton? {
        if let button = view as? NSStatusBarButton { return button }
        for subview in view.subviews {
            if let button = button(in: subview) { return button }
        }
        return nil
    }
}
