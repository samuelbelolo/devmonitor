import AppKit
import SwiftUI

/// Keeps a menu bar window as tall as its content; it goes behind the content, whose size it takes. SwiftUI only
/// raises the window's minimum size as the content grows: when the content shrinks, the window stays tall and the
/// content floats in the middle of it, square-cornered between two see-through bands.
struct WindowFit: NSViewRepresentable {
    /// Returns the view that watches the content's size.
    /// @example makeNSView(context: context) // a view as large as the content
    func makeNSView(context: Context) -> NSView { FittingView() }

    /// Does nothing: the view watches its own size.
    /// @example updateNSView(view, context: context)
    func updateNSView(_ view: NSView, context: Context) {}
}

/// A view the size of the window's content, which shrinks the window back to that size.
private final class FittingView: NSView {
    /// Fits the window it joins, and again each time that window is resized.
    /// @example viewDidMoveToWindow() // called by AppKit
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        NotificationCenter.default.removeObserver(self, name: NSWindow.didResizeNotification, object: nil)
        if let window {
            NotificationCenter.default.addObserver(self, selector: #selector(windowDidResize), name: NSWindow.didResizeNotification, object: window)
        }
        fitSoon()
    }

    /// Fits the window when the content changes size: at once, so that no frame shows the content floating, and
    /// again after the layout pass, because the window refuses a height under its minimum size, which SwiftUI
    /// may only lower then.
    /// @example setFrameSize(NSSize(width: 360, height: 586)) // called by SwiftUI
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        fit()
        fitSoon()
    }

    /// Fits the window after something else resized it.
    /// @example windowDidResize(notification) // called by the notification center
    @objc private func windowDidResize(_ notification: Notification) {
        fit()
    }

    /// Fits the window once the current layout pass is over.
    /// @example fitSoon()
    private func fitSoon() {
        DispatchQueue.main.async { [weak self] in self?.fit() }
    }

    /// Shrinks the window to the content's height, keeping its top edge under the menu bar.
    /// @example fit() // a window 700 points tall around 586 points of content becomes 586 points tall
    private func fit() {
        guard let window, bounds.height > 0, window.frame.height - bounds.height > 0.5 else { return }
        var frame = window.frame
        frame.origin.y += frame.height - bounds.height
        frame.size.height = bounds.height
        window.setFrame(frame, display: false)
    }
}
