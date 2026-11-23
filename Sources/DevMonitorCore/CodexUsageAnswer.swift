import Foundation

/// Reads the answer of Codex's usage address (`GET https://chatgpt.com/backend-api/wham/usage`).
///
/// The limits are the windows of `rate_limit`, named by their length and not by their slot: on 14 November the only
/// window, the primary one, was the week. The extra buckets of `additional_rate_limits` (a code review, one model)
/// are left out: they do not stop the account's main use.
public enum CodexUsageAnswer {
    /// Returns the limits an answer gives; throws when the body is not a JSON object of that shape.
    /// @example try CodexUsageAnswer.usage(from: body).limits.map(\.kind) // [.week]
    public static func usage(from body: Data) throws -> AccountUsage {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let answer = try decoder.decode(Answer.self, from: body)
        let windows = [answer.rateLimit?.primaryWindow, answer.rateLimit?.secondaryWindow].compactMap { $0 }
        let limits = windows.compactMap(limit)
        return AccountUsage(limits: limits, resetCredits: answer.rateLimitResetCredits.map { credits(left: $0.availableCount ?? 0, limits: limits) })
    }

    /// Returns Codex's resets: one count, each reset starting every window again, shown beside the longest window.
    /// The official client offers one whenever the count is above zero; the server keeps it when nothing needs it.
    /// @example credits(left: 3, limits: [week]) // [ResetCredit(id: nil, left: 3, clears: [], shownOn: .week, …)]
    private static func credits(left: Int, limits: [AccountLimit]) -> [ResetCredit] {
        guard left > 0 else { return [] }
        let longest = limits.max { seconds($0.kind) < seconds($1.kind) }?.kind
        return [ResetCredit(id: nil, left: left, clears: [], shownOn: longest, endsAt: nil)]
    }

    /// Returns the length of a window kind in seconds, to find the longest.
    /// @example seconds(.week) // 604800
    private static func seconds(_ kind: AccountLimit.Kind) -> Int {
        switch kind {
        case .week, .weekOnModel: 604_800
        case .fiveHours: 18_000
        case .window(let seconds): seconds
        case .other: 0
        }
    }

    /// Returns the limit a window describes; nil when it gives no share used.
    /// @example limit(Window(usedPercent: 55, limitWindowSeconds: 604_800, resetAt: 1_795_008_058))?.kind // .week
    private static func limit(_ window: Window) -> AccountLimit? {
        guard let used = window.usedPercent else { return nil }
        let kind = window.limitWindowSeconds.map(kind(ofWindow:)) ?? .other("codex")
        return AccountLimit(kind: kind, percentUsed: used, resetsAt: window.resetAt.map { Date(timeIntervalSince1970: $0) })
    }

    /// Returns the kind of a window by its length, within 5 %: five hours, the week, or a window of that length.
    /// @example kind(ofWindow: 604_800) // .week
    static func kind(ofWindow seconds: Int) -> AccountLimit.Kind {
        func near(_ target: Double) -> Bool { abs(Double(seconds) - target) <= target * 0.05 }
        if near(5 * 3600) { return .fiveHours }
        if near(7 * 86_400) { return .week }
        return .window(seconds: seconds)
    }

    /// The keys of the answer DevMonitor reads.
    private struct Answer: Decodable {
        let rateLimit: RateLimit?
        let rateLimitResetCredits: Credits?
    }

    /// The free resets the account has.
    private struct Credits: Decodable {
        let availableCount: Int?
    }

    /// The main limits of the account.
    private struct RateLimit: Decodable {
        let primaryWindow: Window?
        let secondaryWindow: Window?
    }

    /// One window: the share used, its length, and when it starts again, in Unix seconds.
    private struct Window: Decodable {
        let usedPercent: Double?
        let limitWindowSeconds: Int?
        let resetAt: Double?
    }
}
