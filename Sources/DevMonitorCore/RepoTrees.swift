import Foundation

/// Asks GitHub for the tree of each skill repository, anonymously. The anonymous API allows 60 requests an hour per
/// address, shared with the `skills` tool, and a 304 counts like any other answer. So the git server is asked first
/// which commit the ref points to, outside that limit; the API is asked only when the commit is not the one of the
/// tree already known. Answers are remembered for as long as the app runs, and a refused or failed request leaves
/// the last tree in place.
public actor RepoTrees {
    /// Sends a request and returns the body, the status and the ETag of the answer; nil when nothing came back.
    public typealias Load = @Sendable (URLRequest) async -> (data: Data, status: Int, etag: String?)?

    private struct Answer: Sendable {
        let etag: String?
        let tree: RepoTree
        /// The commit the tree was read at; nil when the git server did not say.
        let commit: String?
    }

    /// What GitHub said about one source this time.
    private enum Reply: Sendable {
        case changed(Answer)
        /// The tree already known is still the current one, now known to be at this commit.
        case unchanged(commit: String?)
        case none
    }

    private var known: [SkillSource: Answer] = [:]
    /// When GitHub last answered about at least one source, with a new tree or with "unchanged"; nil until it does.
    public private(set) var lastAnswered: Date?
    private let heads: RepoHeads.Load
    private let load: Load

    public init(heads: @escaping RepoHeads.Load = RepoHeads.overTheNetwork, load: @escaping Load = RepoTrees.overTheNetwork) {
        self.heads = heads
        self.load = load
    }

    /// Returns the tree of each source that answered now or earlier; the requests run side by side.
    /// @example await trees.fetch([SkillSource(repo: "vercel-labs/skills", ref: nil)]).count // 1
    public func fetch(_ sources: [SkillSource]) async -> [SkillSource: RepoTree] {
        let wanted = Set(sources)
        let known = known
        let heads = heads
        let load = load
        let replies = await withTaskGroup(of: (SkillSource, Reply).self) { group in
            for source in wanted {
                group.addTask { (source, await Self.reply(for: source, known: known[source], heads: heads, load: load)) }
            }
            var replies: [(SkillSource, Reply)] = []
            for await reply in group { replies.append(reply) }
            return replies
        }
        for (source, reply) in replies {
            switch reply {
            case .changed(let answer):
                self.known[source] = answer
                lastAnswered = Date()
            case .unchanged(let commit):
                guard let last = self.known[source] else { break }
                self.known[source] = Answer(etag: last.etag, tree: last.tree, commit: commit ?? last.commit)
                lastAnswered = Date()
            case .none:
                break
            }
        }
        return self.known.filter { wanted.contains($0.key) }.mapValues(\.tree)
    }

    /// Asks about one source: "unchanged" when its commit is the known one, else the API for the tree at that commit
    /// (or at the ref when the git server did not answer); nothing when refused, unreadable or without an address.
    /// @example await reply(for: source, known: answer, heads: heads, load: load) // .unchanged(commit: "13e4…")
    private static func reply(for source: SkillSource, known: Answer?, heads: RepoHeads.Load, load: Load) async -> Reply {
        let commit = await heads(source)
        if let commit, commit == known?.commit { return .unchanged(commit: commit) }
        guard let url = source.treeURL(at: commit) else { return .none }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        if let etag = known?.etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        guard let response = await load(request) else { return .none }
        if response.status == 304 { return .unchanged(commit: commit) }
        guard response.status == 200, let tree = RepoTree(parsing: response.data) else { return .none }
        return .changed(Answer(etag: response.etag, tree: tree, commit: commit))
    }

    /// A session that keeps its cache and cookies in memory, so no answer is written to disk.
    private static let session = URLSession(configuration: .ephemeral)

    /// The real loader: one HTTPS request, with no token.
    public static let overTheNetwork: Load = { request in
        guard let (data, response) = try? await session.data(for: request), let http = response as? HTTPURLResponse else { return nil }
        return (data, http.statusCode, http.value(forHTTPHeaderField: "ETag"))
    }
}
