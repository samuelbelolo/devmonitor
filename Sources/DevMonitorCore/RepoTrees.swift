import Foundation

/// Asks GitHub for the tree of each skill repository, anonymously. It remembers each answer and its ETag for as
/// long as the app runs: an unchanged repository then answers 304, which does not count against the hourly limit
/// of anonymous requests, and a refused or failed request leaves the last tree in place.
public actor RepoTrees {
    /// Sends a request and returns the body, the status and the ETag of the answer; nil when nothing came back.
    public typealias Load = @Sendable (URLRequest) async -> (data: Data, status: Int, etag: String?)?

    private struct Answer: Sendable {
        let etag: String?
        let tree: RepoTree
    }

    /// What GitHub said about one source this time.
    private enum Reply: Sendable {
        case changed(Answer)
        /// A 304: the tree already known is still the current one.
        case unchanged
        case none
    }

    private var known: [SkillSource: Answer] = [:]
    /// When GitHub last answered about at least one source, with a new tree or with "unchanged"; nil until it does.
    public private(set) var lastAnswered: Date?
    private let load: Load

    public init(load: @escaping Load = RepoTrees.overTheNetwork) {
        self.load = load
    }

    /// Returns the tree of each source that answered now or earlier; the requests run side by side.
    /// @example await trees.fetch([SkillSource(repo: "vercel-labs/skills", ref: nil)]).count // 1
    public func fetch(_ sources: [SkillSource]) async -> [SkillSource: RepoTree] {
        let wanted = Set(sources)
        let known = known
        let load = load
        let replies = await withTaskGroup(of: (SkillSource, Reply).self) { group in
            for source in wanted {
                group.addTask { (source, await Self.reply(for: source, etag: known[source]?.etag, load: load)) }
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
            case .unchanged where self.known[source] != nil:
                lastAnswered = Date()
            case .unchanged, .none:
                break
            }
        }
        return self.known.filter { wanted.contains($0.key) }.mapValues(\.tree)
    }

    /// Asks GitHub about one source: a new tree, "unchanged" on a 304, or nothing when it is refused, unreadable or has no address.
    /// @example await reply(for: source, etag: "\"v1\"", load: load) // .unchanged on a 304
    private static func reply(for source: SkillSource, etag: String?, load: Load) async -> Reply {
        guard let url = source.treeURL else { return .none }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        guard let response = await load(request) else { return .none }
        if response.status == 304 { return .unchanged }
        guard response.status == 200, let tree = RepoTree(parsing: response.data) else { return .none }
        return .changed(Answer(etag: response.etag, tree: tree))
    }

    /// A session that keeps its cache and cookies in memory, so no answer is written to disk.
    private static let session = URLSession(configuration: .ephemeral)

    /// The real loader: one HTTPS request, with no token.
    public static let overTheNetwork: Load = { request in
        guard let (data, response) = try? await session.data(for: request), let http = response as? HTTPURLResponse else { return nil }
        return (data, http.statusCode, http.value(forHTTPHeaderField: "ETag"))
    }
}
