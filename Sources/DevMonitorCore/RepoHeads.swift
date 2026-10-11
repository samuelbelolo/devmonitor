import Foundation

/// Asks GitHub's git server, the way `git ls-remote` does, which commit a skill source's ref points to. The answer
/// is a few hundred bytes and does not count against the hourly limit of the API, so it can be asked often; the
/// tree is then fetched from the API only when the commit changed.
public enum RepoHeads {
    /// Returns the commit a source's ref points to; nil when the server did not answer or has no such ref.
    public typealias Load = @Sendable (SkillSource) async -> String?

    /// Returns the protocol version 2 `ls-refs` request for the source's ref; nil when the source has no address.
    /// @example RepoHeads.request(for: SkillSource(repo: "acme/kit", ref: nil))?.httpMethod // "POST"
    public static func request(for source: SkillSource) -> URLRequest? {
        guard let url = source.uploadPackURL else { return nil }
        var body = PktLine.encode("command=ls-refs\n") + PktLine.delimiter + PktLine.encode("peel\n")
        for name in wantedRefs(of: source) { body += PktLine.encode("ref-prefix \(name)\n") }
        body += PktLine.flush
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.httpBody = Data(body.utf8)
        request.setValue("application/x-git-upload-pack-request", forHTTPHeaderField: "Content-Type")
        request.setValue("version=2", forHTTPHeaderField: "Git-Protocol")
        return request
    }

    /// Returns the commit of the source's ref in an `ls-refs` answer: the branch before a tag of the same name, and
    /// a tag's target rather than the tag itself; nil when the ref is absent or the answer is not one.
    /// @example RepoHeads.commit(in: answer, for: SkillSource(repo: "acme/kit", ref: nil)) // "13e4…"
    public static func commit(in data: Data, for source: SkillSource) -> String? {
        var found: [String: String] = [:]
        for line in PktLine.lines(in: data) {
            let parts = line.split(separator: " ").map(String.init)
            guard parts.count >= 2 else { continue }
            let peeled = parts.dropFirst(2).first { $0.hasPrefix("peeled:") }.map { String($0.dropFirst("peeled:".count)) }
            found[parts[1]] = peeled ?? parts[0]
        }
        return wantedRefs(of: source).lazy.compactMap { found[$0] }.first(where: SkillSource.isCommitHash)
    }

    /// Returns the full names the source's ref may have, in order of preference.
    /// @example wantedRefs(of: SkillSource(repo: "acme/kit", ref: "v2")) // ["refs/heads/v2", "refs/tags/v2"]
    private static func wantedRefs(of source: SkillSource) -> [String] {
        guard let ref = source.ref else { return ["HEAD"] }
        return ["refs/heads/\(ref)", "refs/tags/\(ref)"]
    }

    /// A session that keeps its cache and cookies in memory, so no answer is written to disk.
    private static let session = URLSession(configuration: .ephemeral)

    /// The real loader: one HTTPS request, with no token.
    public static let overTheNetwork: Load = { source in
        guard let request = request(for: source),
              let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return commit(in: data, for: source)
    }
}
