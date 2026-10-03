import AppKit
import SwiftUI

/// Hosts a SwiftUI view in a real window and clicks in it, so a test exercises the same hit-testing as the app.
@MainActor
final class HostedView {
    private let window: NSWindow

    /// Shows the view in a borderless window of the given size.
    /// @example HostedView(Text("hi"), width: 200, height: 30)
    init<Content: View>(_ view: Content, width: CGFloat, height: CGFloat) {
        _ = NSApplication.shared
        window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: width, height: height), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: view.frame(width: width, height: height))
        window.orderFrontRegardless()
        settle()
    }

    /// Presses and releases the mouse at a point given from the top-left corner of the view, then lets the view react.
    /// @example hosted.click(x: 191, y: 15)
    func click(x: CGFloat, y: CGFloat) {
        let location = NSPoint(x: x, y: window.frame.height - y)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = NSEvent.mouseEvent(
                with: type, location: location, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0)
            if let event { NSApp.postEvent(event, atStart: false) }
        }
        settle()
    }

    /// Dispatches the pending events and lets SwiftUI update for a short while.
    /// @example settle()
    func settle(for seconds: TimeInterval = 0.3) {
        let end = Date().addingTimeInterval(seconds)
        while Date() < end {
            if let event = NSApp.nextEvent(matching: .any, until: Date().addingTimeInterval(0.02), inMode: .default, dequeue: true) {
                NSApp.sendEvent(event)
            }
        }
    }
}
