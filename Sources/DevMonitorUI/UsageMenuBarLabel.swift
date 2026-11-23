import AppKit
import DevMonitorCore
import SwiftUI

/// The menu bar label of the accounts item: Claude's logo and the share used of the fullest limit of the Claude
/// account most running sessions draw on, then Codex's logo and the share used of its fullest limit. Each part shows
/// only when its provider has an account followed, and each share turns orange from 80 % and red from 95 %. When that
/// Claude account is full, Claude's share is followed by the wait until it is usable again.
public struct UsageMenuBarLabel: View {
    @EnvironmentObject private var usage: UsageStore

    /// One provider's part of the label.
    struct Part: Equatable {
        let agent: Agent
        let text: String
        let tint: Color?
        /// What follows the share in the menu bar's secondary color, such as the wait until an account is free.
        var detail: String? = nil
    }

    public init() {}

    public var body: some View {
        // A menu bar label shows only an image or a text, so the countdown ticks with the store's clock, not a timeline.
        Image(nsImage: UsageGlyph.image(for: Self.parts(followsClaude: usage.follows(.claude), claudePercent: usage.busiestClaudePercent,
                                                         followsCodex: usage.follows(.codex), codexFullest: usage.codexFullest,
                                                         claudeFreeIn: usage.claudeFreeAgainAt.map { $0.timeIntervalSince(usage.clock) })))
    }

    /// Returns the parts of the label: Claude's while a Claude account is followed or while nothing is, a "+" in the
    /// latter case; Codex's while a Codex account is. Claude's carries the wait, in seconds, until the Claude account shown
    /// is free again when it is full.
    /// @example UsageMenuBarLabel.parts(followsClaude: true, claudePercent: 97, followsCodex: false, codexFullest: nil, claudeFreeIn: 6_120) // [Claude "97 %" "1 h 42 min"]
    static func parts(followsClaude: Bool, claudePercent: Double?, followsCodex: Bool, codexFullest: Double?,
                      claudeFreeIn: TimeInterval? = nil) -> [Part] {
        var parts: [Part] = []
        if followsClaude {
            parts.append(Part(agent: .claude, text: text(percentUsed: claudePercent), tint: claudePercent.flatMap(tint(percentUsed:)),
                              detail: claudeFreeIn.map { UsageStrings.countdown(Int($0.rounded(.up))) }))
        } else if !followsCodex {
            parts.append(Part(agent: .claude, text: "+", tint: nil))
        }
        if followsCodex {
            parts.append(Part(agent: .codex, text: text(percentUsed: codexFullest), tint: codexFullest.flatMap(tint(percentUsed:))))
        }
        return parts
    }

    /// Returns a share used as the menu bar writes it: "–" when it is not known.
    /// @example UsageMenuBarLabel.text(percentUsed: 54.6) // "55 %"
    static func text(percentUsed: Double?) -> String {
        percentUsed.map { "\(Int($0.rounded()))\u{00A0}%" } ?? "–"
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
    /// @example UsageGlyph.image(for: [Part(agent: .claude, text: "17 %", tint: nil)]).size.width // 40
    static func image(for parts: [UsageMenuBarLabel.Part]) -> NSImage {
        let font = NSFont.menuBarFont(ofSize: 0)
        let drawn = parts.map { part in
            (logo: AgentGlyph.image(for: [AgentGlyph.Logo(agent: part.agent, frame: 0, badge: false)]),
             text: part.text as NSString, tint: part.tint.map { NSColor($0) },
             detail: part.detail.map { " · \($0)" as NSString },
             width: ceil((part.text as NSString).size(withAttributes: [.font: font]).width),
             detailWidth: part.detail.map { ceil((" · \($0)" as NSString).size(withAttributes: [.font: font]).width) } ?? 0)
        }
        let height = max(logoSize.height, ceil(font.ascender - font.descender))
        let width = drawn.reduce(0) { $0 + logoSize.width + afterLogo + $1.width + $1.detailWidth } + CGFloat(max(drawn.count - 1, 0)) * betweenParts
        let image = NSImage(size: NSSize(width: max(width, 1), height: height), flipped: false) { _ in
            var x: CGFloat = 0
            for part in drawn {
                part.logo.draw(in: NSRect(origin: NSPoint(x: x, y: (height - logoSize.height) / 2), size: logoSize))
                x += logoSize.width + afterLogo
                // The point is the bottom of the text's line, a descender below its baseline: the digits' height is
                // centred on the logos'.
                part.text.draw(at: NSPoint(x: x, y: (height - font.capHeight) / 2 + font.descender),
                               withAttributes: [.font: font, .foregroundColor: part.tint ?? NSColor.labelColor])
                x += part.width
                part.detail?.draw(at: NSPoint(x: x, y: (height - font.capHeight) / 2 + font.descender),
                                  withAttributes: [.font: font, .foregroundColor: NSColor.secondaryLabelColor])
                x += part.detailWidth + betweenParts
            }
            return true
        }
        image.isTemplate = false
        return image
    }
}
