import AppKit
import DevMonitorCore
import SwiftUI

/// The menu bar label of the accounts item: Claude's logo and how many Claude accounts have room out of how many are
/// followed, then Codex's logo and the share used of its fullest limit. Each part shows only when its provider has an
/// account followed. Claude's count turns orange when one account has room left and red when none has; Codex's
/// share, orange from 80 % and red from 95 %.
public struct UsageMenuBarLabel: View {
    @EnvironmentObject private var usage: UsageStore

    /// One provider's part of the label.
    struct Part: Equatable {
        let agent: Agent
        let text: String
        let tint: Color?
    }

    public init() {}

    public var body: some View {
        let count = usage.roomCount
        Image(nsImage: UsageGlyph.image(for: Self.parts(withRoom: count.withRoom, total: count.total, followsCodex: usage.follows(.codex), codexFullest: usage.codexFullest)))
    }

    /// Returns the parts of the label: Claude's while a Claude account is followed or while nothing is, Codex's while
    /// a Codex account is.
    /// @example UsageMenuBarLabel.parts(withRoom: 0, total: 0, followsCodex: true, codexFullest: 55) // [Codex "55 %"]
    static func parts(withRoom: Int, total: Int, followsCodex: Bool, codexFullest: Double?) -> [Part] {
        var parts: [Part] = []
        if total > 0 || !followsCodex {
            parts.append(Part(agent: .claude, text: text(withRoom: withRoom, total: total), tint: tint(withRoom: withRoom, total: total)))
        }
        if followsCodex {
            parts.append(Part(agent: .codex, text: codexFullest.map { "\(Int($0.rounded())) %" } ?? "–", tint: codexFullest.flatMap(tint(percentUsed:))))
        }
        return parts
    }

    /// Returns the Claude count: "+" while no account is followed.
    /// @example UsageMenuBarLabel.text(withRoom: 2, total: 3) // "2/3"
    static func text(withRoom: Int, total: Int) -> String {
        total == 0 ? "+" : "\(withRoom)/\(total)"
    }

    /// Returns the color of the Claude count: red when no followed account has room, orange when one has; nil otherwise.
    /// @example UsageMenuBarLabel.tint(withRoom: 1, total: 5) // LimitTint.orange
    static func tint(withRoom: Int, total: Int) -> Color? {
        guard total > 0 else { return nil }
        if withRoom == 0 { return Palette.orphan }
        return withRoom == 1 ? LimitTint.orange : nil
    }

    /// Returns the color of a share used: red from 95 %, orange from 80 %; nil below.
    /// @example UsageMenuBarLabel.tint(percentUsed: 96) // Palette.orphan
    static func tint(percentUsed: Double) -> Color? {
        LimitTint.color(percentUsed: percentUsed)
    }
}

/// Draws the label of the accounts item as one image: the menu bar shows one image per item, and a part's text drawn
/// here takes the menu bar's own text color unless it has a tint.
@MainActor
enum UsageGlyph {
    private static let logoSize = NSSize(width: 16, height: 16)
    private static let afterLogo: CGFloat = 4
    private static let betweenParts: CGFloat = 9

    /// Returns the parts side by side, each its logo then its text.
    /// @example UsageGlyph.image(for: [Part(agent: .claude, text: "2/3", tint: nil)]).size.width // 40
    static func image(for parts: [UsageMenuBarLabel.Part]) -> NSImage {
        let font = NSFont.menuBarFont(ofSize: 0)
        let drawn = parts.map { part in
            (logo: AgentGlyph.image(for: [AgentGlyph.Logo(agent: part.agent, frame: 0, badge: false)]),
             text: part.text as NSString, tint: part.tint.map { NSColor($0) },
             width: ceil((part.text as NSString).size(withAttributes: [.font: font]).width))
        }
        let height = max(logoSize.height, ceil(font.ascender - font.descender))
        let width = drawn.reduce(0) { $0 + logoSize.width + afterLogo + $1.width } + CGFloat(max(drawn.count - 1, 0)) * betweenParts
        let image = NSImage(size: NSSize(width: max(width, 1), height: height), flipped: false) { _ in
            var x: CGFloat = 0
            for part in drawn {
                part.logo.draw(in: NSRect(origin: NSPoint(x: x, y: (height - logoSize.height) / 2), size: logoSize))
                x += logoSize.width + afterLogo
                // The point is the bottom of the text's line, a descender below its baseline: the digits' height is
                // centred on the logos'.
                part.text.draw(at: NSPoint(x: x, y: (height - font.capHeight) / 2 + font.descender),
                               withAttributes: [.font: font, .foregroundColor: part.tint ?? NSColor.labelColor])
                x += part.width + betweenParts
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}
