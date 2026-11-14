import AppKit
import DevMonitorCore
import SwiftUI

/// The menu bar label of the accounts item: Claude's logo, then how many accounts have room out of how many are
/// followed, or a "+" while none is. The count turns orange when one account has room left, red when none has.
public struct UsageMenuBarLabel: View {
    @EnvironmentObject private var usage: UsageStore

    public init() {}

    public var body: some View {
        let count = usage.roomCount
        let text = Self.text(withRoom: count.withRoom, total: count.total)
        Image(nsImage: AgentGlyph.image(for: [AgentGlyph.Logo(agent: .claude, frame: 0, badge: false)]))
        if let tint = Self.tint(withRoom: count.withRoom, total: count.total) {
            Image(nsImage: Self.coloredText(text, NSColor(tint)))
        } else {
            Text(text)
        }
    }

    /// Returns the count shown in the menu bar: "+" while no account is followed, so the item says what it is for.
    /// @example UsageMenuBarLabel.text(withRoom: 2, total: 3) // "2/3"
    static func text(withRoom: Int, total: Int) -> String {
        total == 0 ? "+" : "\(withRoom)/\(total)"
    }

    /// Returns the color of the count: red when no followed account has room, orange when one has; nil otherwise.
    /// @example UsageMenuBarLabel.tint(withRoom: 1, total: 5) // Palette.idle
    static func tint(withRoom: Int, total: Int) -> Color? {
        guard total > 0 else { return nil }
        if withRoom == 0 { return Palette.orphan }
        return withRoom == 1 ? Palette.idle : nil
    }

    /// Draws the count in a color: the menu bar paints a label's text in its own color, an image keeps its own.
    /// @example coloredText("1/5", .orange).isTemplate // false
    private static func coloredText(_ text: String, _ color: NSColor) -> NSImage {
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.menuBarFont(ofSize: 0), .foregroundColor: color]
        let size = (text as NSString).size(withAttributes: attributes)
        let image = NSImage(size: NSSize(width: ceil(size.width), height: ceil(size.height)), flipped: false) { _ in
            (text as NSString).draw(at: .zero, withAttributes: attributes)
            return true
        }
        image.isTemplate = false
        return image
    }
}
