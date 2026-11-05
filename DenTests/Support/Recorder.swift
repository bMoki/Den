import Foundation

nonisolated final class Recorder: @unchecked Sendable {
    private let lock = NSLock()
    private var entries: [String] = []

    var all: [String] { lock.withLock { entries } }

    func append(_ entry: String) { lock.withLock { entries.append(entry) } }
}
