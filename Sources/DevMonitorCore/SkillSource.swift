import Foundation

/// Where skills come from: a GitHub repository, and the branch or tag they were installed from, if any.
public struct SkillSource: Hashable, Sendable {
    public let repo: String
    public let ref: String?

    public init(repo: String, ref: String?) {
        self.repo = repo
        self.ref = ref
    }

    /// The source as shown in the list: the repository, then the ref when there is one.
    public var name: String { ref.map { "\(repo)@\($0)" } ?? repo }

    /// Whether the repository is written `owner/name`, the only form that goes into an address.
    private var isPlainRepo: Bool {
        repo.range(of: #"^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil
    }

    /// The address of the repository's whole tree at the ref; nil when the repository is not written `owner/name`.
    public var treeURL: URL? { treeURL(at: nil) }

    /// Returns the address of the repository's whole tree at a commit, or at the ref when `commit` is nil; nil when
    /// the repository is not written `owner/name` or the commit is not a hash.
    /// @example source.treeURL(at: "13e4…")?.lastPathComponent // "13e4…"
    public func treeURL(at commit: String?) -> URL? {
        guard isPlainRepo else { return nil }
        if let commit {
            guard Self.isCommitHash(commit) else { return nil }
            return URL(string: "https://api.github.com/repos/\(repo)/git/trees/\(commit)?recursive=1")
        }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "._-")
        guard let branch = (ref ?? "HEAD").addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "https://api.github.com/repos/\(repo)/git/trees/\(branch)?recursive=1")
    }

    /// The address git asks for the repository's refs; outside the API, so not counted against its hourly limit.
    public var uploadPackURL: URL? {
        isPlainRepo ? URL(string: "https://github.com/\(repo).git/git-upload-pack") : nil
    }

    /// Whether a text is a full commit hash, SHA-1 or SHA-256.
    /// @example SkillSource.isCommitHash("main") // false
    public static func isCommitHash(_ text: String) -> Bool {
        text.range(of: "^[0-9a-f]{40}([0-9a-f]{24})?$", options: .regularExpression) != nil
    }
}
