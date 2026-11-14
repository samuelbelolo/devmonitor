import Foundation

/// Reads the free resets of a Claude usage answer: its `cedar_ember` block, which Claude fills only for a read that
/// asks for it (`?cedar_ember=1`) and calls itself Claude Code. Each grant lists the limits it starts again, by the
/// names of the answer's windows: `seven_day` is the week, and `seven_day_overage_included` the week on the one model
/// the answer scopes a limit to (Fable on 14 November: its share matched Fable's on every account read).
enum ClaudeResetGrants {
    /// Returns the grants with resets left that can be spent now; nil when the answer carries no `cedar_ember` object.
    /// @example ClaudeResetGrants.credits(from: body, limits: usage.limits)?.first?.shownOn // .weekOnModel("Fable")
    static func credits(from body: Data, limits: [AccountLimit]) -> [ResetCredit]? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let block = (try? decoder.decode(Answer.self, from: body))?.cedarEmber else { return nil }
        let grants = (block.grants ?? []).filter { ($0.resetsLeft ?? 0) > 0 && $0.paused != true && $0.usableNow != false && $0.id != nil }
        let ordered = grants.filter { $0.id == block.nextGrantId } + grants.filter { $0.id != block.nextGrantId }
        return ordered.map { credit($0, limits: limits) }
    }

    /// Returns the reset a grant gives, shown beside the broadest limit it starts again.
    /// @example credit(grant, limits: limits).shownOn // .week
    private static func credit(_ grant: Grant, limits: [AccountLimit]) -> ResetCredit {
        let clears = (grant.clears ?? []).map { kind(ofWindow: $0, limits: limits) }
        let shown: AccountLimit.Kind? = if clears.contains(.week) {
            .week
        } else if clears.count == 1, case .other = clears[0] {
            nil
        } else {
            clears.count == 1 ? clears[0] : nil
        }
        return ResetCredit(id: grant.id, left: grant.resetsLeft ?? 0, clears: clears, shownOn: shown, endsAt: grant.endsAt.flatMap(Timestamp.date))
    }

    /// Returns the limit a window name stands for; a name DevMonitor does not know stays as it is.
    /// @example kind(ofWindow: "seven_day", limits: limits) // .week
    private static func kind(ofWindow name: String, limits: [AccountLimit]) -> AccountLimit.Kind {
        switch name {
        case "seven_day": return .week
        case "five_hour": return .fiveHours
        case "seven_day_overage_included":
            let models = limits.compactMap { limit -> AccountLimit.Kind? in
                if case .weekOnModel = limit.kind { return limit.kind }
                return nil
            }
            return models.count == 1 ? models[0] : .other(name)
        default: return .other(name)
        }
    }

    /// The part of the answer that holds the grants.
    private struct Answer: Decodable {
        let cedarEmber: Block?
    }

    /// The `cedar_ember` object.
    private struct Block: Decodable {
        let nextGrantId: String?
        let grants: [Grant]?
    }

    /// One grant of resets.
    private struct Grant: Decodable {
        let id: String?
        let resetsLeft: Int?
        let endsAt: String?
        let clears: [String]?
        let paused: Bool?
        let usableNow: Bool?
    }
}
