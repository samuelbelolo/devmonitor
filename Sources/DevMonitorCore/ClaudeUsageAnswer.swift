import Foundation

/// Reads the answer of Claude's usage address (`GET https://api.anthropic.com/api/oauth/usage`).
///
/// The limits come from `limits[]`, which names each one: `weekly_all` is the week, `weekly_scoped` the week on the
/// model its scope names, `session` the five hours. `seven_day` gives the week too and is read only when `limits[]`
/// lists nothing. `five_hour` gives the five hours too and is added only when it is not null and `limits[]` has no
/// `session`: an answer can carry both, with the same figures. Every other key is left alone, and so is `is_active`,
/// whose meaning is unknown.
public enum ClaudeUsageAnswer {
    /// Returns the limits an answer gives; throws when the body is not a JSON object of that shape.
    /// @example try ClaudeUsageAnswer.usage(from: body).room // 83
    public static func usage(from body: Data) throws -> AccountUsage {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let answer = try decoder.decode(Answer.self, from: body)
        var limits = (answer.limits ?? []).compactMap(limit)
        if limits.isEmpty, let week = answer.sevenDay.flatMap({ window($0, kind: .week) }) {
            limits.append(week)
        }
        if !limits.contains(where: { $0.kind == .fiveHours }),
           let fiveHours = answer.fiveHour.flatMap({ window($0, kind: .fiveHours) }) {
            limits.append(fiveHours)
        }
        return AccountUsage(limits: limits, resetCredits: ClaudeResetGrants.credits(from: body, limits: limits))
    }

    /// Returns the limit an entry of `limits[]` describes; nil when it gives no share used.
    /// @example limit(Entry(kind: "weekly_all", percent: 15, …))?.kind // .week
    private static func limit(_ entry: Entry) -> AccountLimit? {
        guard let percent = entry.percent else { return nil }
        let kind: AccountLimit.Kind = switch (entry.kind, entry.scope?.model?.displayName) {
        case ("weekly_all", _): .week
        case ("weekly_scoped", let model?): .weekOnModel(model)
        case ("session", _): .fiveHours
        case (let name, _): .other(name ?? "unknown")
        }
        return AccountLimit(kind: kind, percentUsed: percent, resetsAt: entry.resetsAt.flatMap(Timestamp.date))
    }

    /// Returns the limit a window such as `seven_day` describes; nil when it gives no share used.
    /// @example window(Window(utilization: 15, resetsAt: nil), kind: .week)?.percentUsed // 15
    private static func window(_ window: Window, kind: AccountLimit.Kind) -> AccountLimit? {
        window.utilization.map { AccountLimit(kind: kind, percentUsed: $0, resetsAt: window.resetsAt.flatMap(Timestamp.date)) }
    }

    /// The keys of the answer DevMonitor reads.
    private struct Answer: Decodable {
        let fiveHour: Window?
        let sevenDay: Window?
        let limits: [Entry]?
    }

    /// A window given as its own key, such as `seven_day`.
    private struct Window: Decodable {
        let utilization: Double?
        let resetsAt: String?
    }

    /// One entry of `limits[]`.
    private struct Entry: Decodable {
        let kind: String?
        let percent: Double?
        let resetsAt: String?
        let scope: Scope?
    }

    /// What a scoped limit applies to.
    private struct Scope: Decodable {
        let model: Model?
    }

    /// The model a scoped limit applies to.
    private struct Model: Decodable {
        let displayName: String?
    }
}
