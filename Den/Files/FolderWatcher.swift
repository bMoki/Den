import CoreServices
import Foundation

nonisolated final class FolderWatcher: @unchecked Sendable {
    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "FolderWatcher")
    private let changed: @Sendable ([String]) -> Void

    private init?(paths: [String], latency: TimeInterval, changed: @escaping @Sendable ([String]) -> Void) {
        self.changed = changed
        var context = FSEventStreamContext(
            version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
            retain: { info in info.map { UnsafeRawPointer(Unmanaged<FolderWatcher>.fromOpaque($0).retain().toOpaque()) } },
            release: { info in info.map { Unmanaged<FolderWatcher>.fromOpaque($0).release() } },
            copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, _, paths, _, _ in
            guard let info, let paths = unsafeBitCast(paths, to: NSArray.self) as? [String] else { return }
            Unmanaged<FolderWatcher>.fromOpaque(info).takeUnretainedValue().changed(paths)
        }
        let flags = kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer | kFSEventStreamCreateFlagWatchRoot
        guard let stream = FSEventStreamCreate(nil, callback, &context, paths as CFArray,
                                               FSEventStreamEventId(kFSEventStreamEventIdSinceNow), latency,
                                               FSEventStreamCreateFlags(flags)) else { return nil }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    private func stop() {
        queue.async {
            guard let stream = self.stream else { return }
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }

    static func changes(in folder: URL, alsoWatching others: [URL] = [], latency: TimeInterval = 0.2) -> AsyncStream<[String]> {
        let real = folder.realPath
        let shown = folder.path
        return AsyncStream { continuation in
            let watcher = FolderWatcher(paths: [folder.path] + others.map(\.path), latency: latency) { paths in
                continuation.yield(paths.map { Self.path($0, real: real, shown: shown) })
            }
            guard let watcher else {
                continuation.finish()
                return
            }
            continuation.onTermination = { _ in watcher.stop() }
        }
    }

    static func path(_ reported: String, real: String, shown: String) -> String {
        var path = reported.hasSuffix("/") ? String(reported.dropLast()) : reported
        if path == real || path.hasPrefix(real + "/") { path = shown + path.dropFirst(real.count) }
        return path
    }
}

extension URL {
    nonisolated var realPath: String {
        guard let resolved = realpath(path, nil) else { return path }
        defer { free(resolved) }
        return String(cString: resolved)
    }
}
