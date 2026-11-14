import CoreServices
import Foundation

/// Calls back when one of a few files changes, whether a tool rewrites it in place or replaces it; changes that come
/// within `latency` seconds of each other are told once. It watches the folders of the files that exist when it is
/// created: a folder made later is not watched, which `watchesEveryFolder` tells. FSEvents tells most changes within
/// a second, but its daemon serves the whole Mac and tells late or not at all when it is saturated: so the files are
/// also looked at every `checkEvery` seconds, and a change FSEvents did not tell is told then.
public final class FileWatcher: @unchecked Sendable {
    private var stream: FSEventStreamRef?
    /// Looks at the files when FSEvents stays silent.
    private var timer: DispatchSourceTimer?
    /// Where the callbacks run, one at a time.
    private let queue = DispatchQueue(label: "DevMonitor.FileWatcher")
    /// Whether the folder of every file existed, so every file is watched.
    public let watchesEveryFolder: Bool
    /// The watched files, by their path with every link resolved, as FSEvents reports them.
    private let files: Set<String>
    /// What each file looked like when a change was last told; read and written on `queue` only.
    private var told: [String: FileSignature] = [:]
    private let onChange: @Sendable () -> Void

    /// Starts watching the files; nil when none of their folders exists.
    /// @example FileWatcher(files: [NSHomeDirectory() + "/.agents/.skill-lock.json"]) { print("changed") }
    public init?(files: [String], latency: TimeInterval = 1, checkEvery: TimeInterval = 2, onChange: @escaping @Sendable () -> Void) {
        let resolved = files.map(Self.resolved)
        let wanted = Set(resolved.map { ($0 as NSString).deletingLastPathComponent })
        let folders = wanted.filter { FileManager.default.fileExists(atPath: $0) }
        guard !folders.isEmpty else { return nil }
        watchesEveryFolder = folders.count == wanted.count
        self.files = Set(resolved)
        self.onChange = onChange
        told = FileSignature.of(self.files)
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
        queue.setSpecific(key: Self.isOnQueue, value: true)
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + checkEvery, repeating: checkEvery, leeway: .milliseconds(200))
        timer.setEventHandler { [weak self] in self?.look() }
        timer.resume()
        self.timer = timer
    }

    /// Marks the callbacks' queue, so the watcher can tell when it is already running on it.
    private static let isOnQueue = DispatchSpecificKey<Bool>()

    deinit {
        guard let stream else { return }
        let timer = timer
        let stop = {
            timer?.cancel()
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
        }
        // On the callbacks' queue: once this returns no callback runs, and none can reach the freed watcher. A
        // callback holds the watcher while it runs, so the last reference may go away inside one, already on the
        // queue, where waiting for the queue would never return.
        if DispatchQueue.getSpecific(key: Self.isOnQueue) == true { stop() } else { queue.sync(execute: stop) }
        FSEventStreamRelease(stream)
    }

    /// Looks at the files when FSEvents names one of them, or lost track of what changed during a burst and names
    /// only a folder.
    /// @example handle(["/Users/me/.agents/.skill-lock.json"], mustRescan: false)
    private func handle(_ paths: [String], mustRescan: Bool) {
        if mustRescan || paths.contains(where: files.contains) { look() }
    }

    /// Calls back when a watched file is not as it was when a change was last told, so a change is told once,
    /// whether FSEvents names it or stays silent, and an event that comes late for a change already told is not.
    /// @example look() // called by the timer, and when FSEvents names a watched file
    private func look() {
        let current = FileSignature.of(files)
        guard current != told else { return }
        told = current
        onChange()
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
