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

    /// The address of the repository's whole tree at the ref; nil when the repository is not written `owner/name`.
    public var treeURL: URL? {
        guard repo.range(of: #"^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$"#, options: .regularExpression) != nil else { return nil }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "._-")
        guard let branch = (ref ?? "HEAD").addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "https://api.github.com/repos/\(repo)/git/trees/\(branch)?recursive=1")
    }
}
