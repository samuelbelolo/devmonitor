import Foundation

/// Asks GitHub for the tree of each skill repository, anonymously. The anonymous API allows 60 requests an hour per
/// address, shared with the `skills` tool, and an unchanged answer counts like any other. So the git server is
/// asked first which commit the ref points to, outside that limit, and the API only when that commit is not the one
/// of the tree already known. A source the git server gives no commit for is asked by its ref, at most every six
/// hours. Answers are remembered for as long as the app runs; a refused or failed request leaves the last tree.
public actor RepoTrees {
    /// Sends a request and returns the body and the status of the answer; nil when nothing came back.
    public typealias Load = @Sendable (URLRequest) async -> (data: Data, status: Int)?

    private struct Answer: Sendable {
        let tree: RepoTree
        /// The commit the tree was read at; nil when it was asked by its ref.
        let commit: String?
    }

    /// What GitHub said about one source this time.
    private enum Reply: Sendable {
        case changed(Answer)
        /// The commit is the one of the tree already known.
        case unchanged
        case none
    }

    private static let byRefPeriod: TimeInterval = 6 * 3600
    private var known: [SkillSource: Answer] = [:]
    /// When each source was last asked by its ref, because the git server gave no commit for it.
    private var askedByRef: [SkillSource: Date] = [:]
    /// When GitHub last answered about at least one source, with a new tree or with "unchanged"; nil until it does.
    public private(set) var lastAnswered: Date?
    private let load: Load
    private let now: @Sendable () -> Date

    public init(load: @escaping Load = RepoTrees.overTheNetwork, now: @escaping @Sendable () -> Date = { Date() }) {
        self.load = load
        self.now = now
    }

    /// Returns the tree of each source that answered now or earlier; the requests run side by side.
    /// @example await trees.fetch([SkillSource(repo: "vercel-labs/skills", ref: nil)]).count // 1
    public func fetch(_ sources: [SkillSource]) async -> [SkillSource: RepoTree] {
        let wanted = Set(sources)
        let date = now()
        let mayAskByRef = wanted.filter { askedByRef[$0].map { date.timeIntervalSince($0) >= Self.byRefPeriod } ?? true }
        let known = known
        let load = load
        let replies = await withTaskGroup(of: (SkillSource, Reply, Bool).self) { group in
            for source in wanted {
                group.addTask {
                    let (reply, byRef) = await Self.reply(for: source, known: known[source], mayAskByRef: mayAskByRef.contains(source), load: load)
                    return (source, reply, byRef)
                }
            }
            var replies: [(SkillSource, Reply, Bool)] = []
            for await reply in group { replies.append(reply) }
            return replies
        }
        for (source, reply, byRef) in replies {
            if byRef { askedByRef[source] = date }
            switch reply {
            case .changed(let answer):
                self.known[source] = answer
                lastAnswered = now()
            case .unchanged:
                lastAnswered = now()
            case .none:
                break
            }
        }
        return self.known.filter { wanted.contains($0.key) }.mapValues(\.tree)
    }

    /// Asks about one source: "unchanged" when its commit is the known one, else the API for the tree at that commit,
    /// or at the ref when there is no commit and `mayAskByRef`; nothing when refused, unreadable or without an
    /// address. Also returns whether the API was asked by the ref.
    /// @example await reply(for: source, known: answer, mayAskByRef: true, load: load) // (.unchanged, false)
    private static func reply(for source: SkillSource, known: Answer?, mayAskByRef: Bool, load: Load) async -> (Reply, Bool) {
        let commit = await head(of: source, load: load)
        if let commit, commit == known?.commit { return (.unchanged, false) }
        guard commit != nil || mayAskByRef, let url = source.treeURL(at: commit) else { return (.none, false) }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let response = await load(request)
        guard let response, response.status == 200, let tree = RepoTree(parsing: response.data) else { return (.none, commit == nil) }
        return (.changed(Answer(tree: tree, commit: commit)), commit == nil)
    }

    /// Returns the commit a source's ref points to: the ref itself when it is a commit hash, else what the git
    /// server says; nil when it says nothing.
    /// @example await head(of: SkillSource(repo: "acme/kit", ref: nil), load: load) // "13e4…"
    private static func head(of source: SkillSource, load: Load) async -> String? {
        if let ref = source.ref, SkillSource.isCommitHash(ref) { return ref }
        guard let request = RepoHeads.request(for: source), let answer = await load(request), answer.status == 200 else { return nil }
        return RepoHeads.commit(in: answer.data, for: source)
    }

    /// A session that keeps its cache and cookies in memory, so no answer is written to disk.
    private static let session = URLSession(configuration: .ephemeral)

    /// The real loader: one HTTPS request, with no token.
    public static let overTheNetwork: Load = { request in
        guard let (data, response) = try? await session.data(for: request), let http = response as? HTTPURLResponse else { return nil }
        return (data, http.statusCode)
    }
}
