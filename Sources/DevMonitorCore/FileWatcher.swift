import CoreServices
import Foundation

/// Calls back when one of a few files changes, whether a tool rewrites it in place or replaces it; changes that come
/// within `latency` seconds of each other are told once. It watches the folders of the files that exist when it is
/// created: a folder made later is not watched, which `watchesEveryFolder` tells.
public final class FileWatcher: @unchecked Sendable {
    private var stream: FSEventStreamRef?
    /// Where the callbacks run, one at a time.
    private let queue = DispatchQueue(label: "DevMonitor.FileWatcher")
    /// Whether the folder of every file existed, so every file is watched.
    public let watchesEveryFolder: Bool
    /// The watched files, by their path with every link resolved, as FSEvents reports them.
    private let files: Set<String>
    private let onChange: @Sendable () -> Void

    /// Starts watching the files; nil when none of their folders exists.
    /// @example FileWatcher(files: [NSHomeDirectory() + "/.agents/.skill-lock.json"]) { print("changed") }
    public init?(files: [String], latency: TimeInterval = 1, onChange: @escaping @Sendable () -> Void) {
        let resolved = files.map(Self.resolved)
        let wanted = Set(resolved.map { ($0 as NSString).deletingLastPathComponent })
        let folders = wanted.filter { FileManager.default.fileExists(atPath: $0) }
        guard !folders.isEmpty else { return nil }
        watchesEveryFolder = folders.count == wanted.count
        self.files = Set(resolved)
        self.onChange = onChange
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, count, paths, flags, _ in
            guard let info, let paths = unsafeBitCast(paths, to: NSArray.self) as? [String] else { return }
            let mustRescan = (0..<count).contains { flags[$0] & FSEventStreamEventFlags(kFSEventStreamEventFlagMustScanSubDirs) != 0 }
            Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue().handle(paths, mustRescan: mustRescan)
        }
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        guard let stream = FSEventStreamCreate(
            nil, callback, &context, Array(folders) as CFArray, FSEventStreamEventId(kFSEventStreamEventIdSinceNow), latency, flags)
        else { return nil }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    deinit {
        guard let stream else { return }
        // On the callbacks' queue: once this returns no callback runs, and none can reach the freed watcher.
        queue.sync {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
        }
        FSEventStreamRelease(stream)
    }

    /// Calls back once when any of the changed paths is a watched file, or when FSEvents lost track of what changed
    /// during a burst and names only a folder.
    /// @example handle(["/Users/me/.agents/.skill-lock.json"], mustRescan: false)
    private func handle(_ paths: [String], mustRescan: Bool) {
        if mustRescan || paths.contains(where: files.contains) { onChange() }
    }

    /// Returns the path with the links of its folder resolved; the file itself may not exist yet. `realpath` keeps
    /// the `/private` that Foundation's own resolving drops and FSEvents reports.
    /// @example resolved("/tmp/x.json") // "/private/tmp/x.json"
    private static func resolved(_ path: String) -> String {
        let folder = (path as NSString).deletingLastPathComponent
        guard let real = realpath(folder, nil) else { return path }
        defer { free(real) }
        return (String(cString: real) as NSString).appendingPathComponent((path as NSString).lastPathComponent)
    }
}
