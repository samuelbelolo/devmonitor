import AppKit
import SwiftUI
import DevMonitorCore

/// The images of the agents' menu bar items: the agent's logo, turned a little while a session works,
/// with an orange dot when a newer version is published.
enum AgentGlyph {
    /// Positions of a full turn the working logo steps through.
    static let frameCount = 8
    /// Images already drawn, by agent, frame and badge: the menu bar asks again at every tick.
    @MainActor private static var cache: [String: NSImage] = [:]
    private static let size = NSSize(width: 16, height: 16)
    private static let badgeOrange = NSColor(Palette.idle)

    /// Returns the image for one frame. It draws when the menu bar draws it, so a logo without a brand color
    /// takes the menu bar's own text color, light or dark.
    /// @example AgentGlyph.image(for: .claude, frame: 3, badge: true)
    @MainActor static func image(for agent: Agent, frame: Int, badge: Bool) -> NSImage {
        let key = "\(agent.rawValue)-\(frame % frameCount)-\(badge)"
        if let cached = cache[key] { return cached }
        let image = draw(agent, frame: frame, badge: badge)
        cache[key] = image
        return image
    }

    /// Draws one frame of an agent's logo.
    /// @example draw(.claude, frame: 0, badge: false)
    private static func draw(_ agent: Agent, frame: Int, badge: Bool) -> NSImage {
        let logo = AgentBrand.logo(agent)
        let angle = CGFloat(frame % frameCount) * 360 / CGFloat(frameCount)
        let image = NSImage(size: size, flipped: false) { rect in
            let tint = AgentBrand.tint(agent).map { NSColor($0) } ?? NSColor.labelColor
            NSGraphicsContext.saveGraphicsState()
            let turn = NSAffineTransform()
            turn.translateX(by: rect.midX, yBy: rect.midY)
            turn.rotate(byDegrees: -angle)
            turn.translateX(by: -rect.midX, yBy: -rect.midY)
            turn.concat()
            tinted(logo, tint, size: rect.size).draw(in: rect.insetBy(dx: 1, dy: 1))
            NSGraphicsContext.restoreGraphicsState()
            if badge {
                badgeOrange.setFill()
                NSBezierPath(ovalIn: NSRect(x: rect.maxX - 6, y: rect.maxY - 6, width: 6, height: 6)).fill()
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    /// Returns a template logo filled with one color.
    /// @example tinted(BrandIcon.openai.image, .labelColor, size: NSSize(width: 16, height: 16))
    private static func tinted(_ logo: NSImage, _ color: NSColor, size: NSSize) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            logo.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }
}
