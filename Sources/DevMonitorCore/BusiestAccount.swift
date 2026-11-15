import Foundation

/// The account the menu bar speaks for: the one the running sessions draw on most.
public enum BusiestAccount {
    /// Returns, among these account keys, the one most running sessions draw on, the fullest of those tied, then the
    /// first listed. With no session on any of them, the account a new session would sign in with when it is among
    /// them; nil otherwise.
    /// @example BusiestAccount.key(among: ["a", "b"], sessions: ["b": 4], percentUsed: [:], fallback: "a") // "b"
    public static func key(among keys: [String], sessions: [String: Int], percentUsed: [String: Double],
                           fallback: String?) -> String? {
        let busy = keys.enumerated().filter { (sessions[$0.element] ?? 0) > 0 }
        guard !busy.isEmpty else { return fallback.flatMap { keys.contains($0) ? $0 : nil } }
        return busy.max { lhs, rhs in
            let left = (sessions[lhs.element] ?? 0, percentUsed[lhs.element] ?? -1)
            let right = (sessions[rhs.element] ?? 0, percentUsed[rhs.element] ?? -1)
            return left == right ? lhs.offset > rhs.offset : left < right
        }?.element
    }
}
