import AppKit
import SwiftUI
import DevMonitorCore

/// The images of the agents' menu bar items: the agent's logo, turned a little while a session works,
/// with an orange dot when a newer version is published.
enum AgentGlyph {
    /// Positions of a full turn the working logo steps through.
    static let frameCount = 8
    /// Images already drawn, by their logos: the menu bar asks again at every tick.
    @MainActor private static var cache: [String: NSImage] = [:]
    private static let size = NSSize(width: 16, height: 16)
    /// Gap between two logos.
    private static let spacing: CGFloat = 3
    private static let badgeOrange = NSColor(Palette.idle)

    /// One logo of the menu bar item: the agent, its frame, and whether a newer version is published.
    struct Logo: Hashable {
        let agent: Agent
        let frame: Int
        let badge: Bool
    }

    /// Returns the logos side by side in one image. It draws when the menu bar draws it, so a logo without a brand
    /// color takes the menu bar's own text color, light or dark.
    /// @example AgentGlyph.image(for: [Logo(agent: .claude, frame: 3, badge: true)])
    @MainActor static func image(for logos: [Logo]) -> NSImage {
        let key = logos.map { "\($0.agent.rawValue)-\($0.frame % frameCount)-\($0.badge)" }.joined(separator: "+")
        if let cached = cache[key] { return cached }
        let frames = logos.map { draw($0.agent, frame: $0.frame, badge: $0.badge) }
        let width = CGFloat(frames.count) * size.width + CGFloat(max(frames.count - 1, 0)) * spacing
        let image = NSImage(size: NSSize(width: width, height: size.height), flipped: false) { _ in
            for (index, frame) in frames.enumerated() {
                frame.draw(in: NSRect(origin: NSPoint(x: CGFloat(index) * (size.width + spacing), y: 0), size: size))
            }
            return true
        }
        image.isTemplate = false
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
