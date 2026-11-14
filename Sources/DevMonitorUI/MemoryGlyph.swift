import AppKit
import DevMonitorCore
import SwiftUI

/// The image of the memory menu bar item once the swap needs attention: the memory chip in orange or in red.
enum MemoryGlyph {
    private static let size = NSSize(width: 18, height: 16)

    /// Returns the chip filled with the color of the state; nil while the swap is fine, when the item keeps the
    /// menu bar's own color. The image is not a template: the menu bar would paint a template in its text color.
    /// @example MemoryGlyph.image(for: .critical)?.isTemplate // false
    static func image(for state: SwapState) -> NSImage? {
        guard let tint = SwapTint.color(for: state), let chip = NSImage(systemSymbolName: "memorychip", accessibilityDescription: nil) else { return nil }
        let color = NSColor(tint)
        let image = NSImage(size: size, flipped: false) { rect in
            chip.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        image.isTemplate = false
        return image
    }
}
