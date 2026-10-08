import SwiftUI
import XCTest
@testable import DevMonitorUI

@MainActor
final class WindowFitTests: XCTestCase {
    /// The height of the hosted content, which a test changes while the window is open.
    private final class ContentHeight: ObservableObject {
        @Published var value: CGFloat

        init(_ value: CGFloat) { self.value = value }
    }

    private struct Content: View {
        @ObservedObject var height: ContentHeight

        var body: some View {
            Color.blue.frame(width: 200, height: height.value).background(WindowFit())
        }
    }

    /// Shows the content in a borderless window of the given height, sized as SwiftUI sizes a menu bar window:
    /// the content sets the window's minimum size and nothing else.
    /// @example window(showing: ContentHeight(100), height: 300)
    private func window(showing height: ContentHeight, height windowHeight: CGFloat) -> NSWindow {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 200, height: windowHeight), styleMask: [.borderless], backing: .buffered, defer: false)
        let host = NSHostingView(rootView: Content(height: height))
        host.sizingOptions = [.minSize]
        window.contentView = host
        window.orderFrontRegardless()
        settle()
        return window
    }

    /// Lets AppKit and SwiftUI lay out, and run what they put off.
    /// @example settle()
    private func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    }

    func testWindowTallerThanItsContentShrinksToItUnderTheSameTopEdge() {
        let window = window(showing: ContentHeight(100), height: 300)
        XCTAssertEqual(window.frame.height, 100)
        XCTAssertEqual(window.frame.maxY, 500)
    }

    func testWindowShrinksWithItsContentUnderTheSameTopEdge() {
        let height = ContentHeight(300)
        let window = window(showing: height, height: 300)
        XCTAssertEqual(window.frame.height, 300)
        height.value = 120
        settle()
        XCTAssertEqual(window.frame.height, 120)
        XCTAssertEqual(window.frame.maxY, 500)
    }
}
