import Foundation

/// Where the sign-ins are kept between two launches, one per account.
public protocol SignInVault: Sendable {
    /// Keeps a sign-in in place of the one held for its account; throws when it could not be kept.
    /// @example try vault.save(signIn)
    func save(_ signIn: SignIn) throws
    /// Returns the sign-in held for an account; nil when there is none, throws when it could not be read.
    /// @example try vault.signIn(for: id.key)?.account.email // "dev@example.com"
    func signIn(for key: String) throws -> SignIn?
    /// Forgets the sign-in of an account; forgetting one that is not there is fine.
    /// @example try vault.remove(key: id.key)
    func remove(key: String) throws
}

public enum SignInVaultError: Error, Equatable {
    case notSaved
    case unreadable
    case notRemoved
}
