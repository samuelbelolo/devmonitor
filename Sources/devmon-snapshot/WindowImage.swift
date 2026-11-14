import AppKit
import SwiftUI

/// A window that says it sits on a display with two pixels per point, whatever display the Mac has: its content is
/// then drawn as sharp as on a Retina display.
private final class SharpWindow: NSWindow {
    override var backingScaleFactor: CGFloat { 2 }
}

/// Draws a view the way a menu bar window shows it and writes the picture as a PNG.
@MainActor
enum WindowImage {
    private static let scale: CGFloat = 2

    /// Draws a view off screen, dark, at two pixels per point, inside a rounded frame with a shadow on a clear
    /// background, and writes it as a PNG. Returns false when the picture could not be made.
    /// @example await WindowImage.write(SampleWindows.memory(), to: "docs/media/memory-window.png") // true
    @discardableResult
    static func write(_ view: some View, to path: String, cornerRadius: CGFloat = 12, margin: CGFloat = 30) async -> Bool {
        let content = view.background(Color(nsColor: .windowBackgroundColor)).environment(\.colorScheme, .dark).environment(\.displayScale, scale)
        let controller = NSHostingController(rootView: content)
        controller.sizingOptions = [.preferredContentSize]
        let window = SharpWindow(contentViewController: controller)
        window.styleMask = [.borderless]
        window.appearance = NSAppearance(named: .darkAqua)
        // Far outside every display: the window has to be open for its views to appear, not to be seen.
        window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
        window.orderFrontRegardless()
        defer { window.close() }
        let host = controller.view
        host.layoutSubtreeIfNeeded()
        // Lets the views appear and the lists measure themselves.
        try? await Task.sleep(for: .milliseconds(800))
        host.layoutSubtreeIfNeeded()
        // The window keeps the size of the first layout; once the views have settled, it takes the size they need,
        // so the bottom margin is not cut when a row grew meanwhile.
        window.setContentSize(host.fittingSize)
        host.layoutSubtreeIfNeeded()
        let size = host.bounds.size
        guard size.width > 0, size.height > 0, let picture = bitmap(of: size) else { return false }
        host.cacheDisplay(in: host.bounds, to: picture)
        let framedSize = NSSize(width: size.width + 2 * margin, height: size.height + 2 * margin)
        guard let framed = bitmap(of: framedSize), let context = NSGraphicsContext(bitmapImageRep: framed) else { return false }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let frame = NSRect(origin: NSPoint(x: margin, y: margin), size: size)
        let outline = NSBezierPath(roundedRect: frame, xRadius: cornerRadius, yRadius: cornerRadius)
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
        shadow.shadowBlurRadius = 16
        shadow.shadowOffset = NSSize(width: 0, height: -6)
        shadow.set()
        NSColor(calibratedWhite: 0.13, alpha: 1).setFill()
        outline.fill()
        NSGraphicsContext.restoreGraphicsState()
        NSGraphicsContext.saveGraphicsState()
        outline.addClip()
        picture.draw(in: frame)
        NSGraphicsContext.restoreGraphicsState()
        NSColor.white.withAlphaComponent(0.14).setStroke()
        outline.lineWidth = 1
        outline.stroke()
        NSGraphicsContext.restoreGraphicsState()
        guard let data = framed.representation(using: .png, properties: [:]) else { return false }
        return (try? data.write(to: URL(fileURLWithPath: path))) != nil
    }

    /// Returns an empty picture of this size in points, with two pixels per point.
    /// @example bitmap(of: NSSize(width: 400, height: 300))?.pixelsWide // 800
    private static func bitmap(of size: NSSize) -> NSBitmapImageRep? {
        let picture = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale), bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)
        picture?.size = size
        return picture
    }
}
