import Foundation

nonisolated enum FileDiff: Equatable, Sendable {
    case lines([GitDiffLine])
    case unchanged
    case outsideGit
    case failed

    static func of(_ url: URL, editing text: String) async -> FileDiff {
        let folder = url.deletingLastPathComponent().standardizedFileURL
        guard let top = GitRepository.toplevel(containing: folder) else { return .outsideGit }
        let path = String(url.standardizedFileURL.path.dropFirst(top.path.count + 1))
        var tracked = await GitCommand.run(["ls-tree", "--name-only", "HEAD", "--", path], in: top)
        if tracked == nil { tracked = await untrackedWithoutHead(top) }
        guard let tracked else { return .failed }
        var committed = ""
        if !tracked.isEmpty {
            guard let shown = await GitCommand.run(["show", "HEAD:\(path)"], in: top) else { return .failed }
            committed = shown
        }
        let scratch = FileManager.default.temporaryDirectory.appending(path: "thalamus-diff-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: scratch) }
        let old = scratch.appending(path: "a")
        let new = scratch.appending(path: "b")
        do {
            try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
            try Data(committed.utf8).write(to: old)
            try Data(text.utf8).write(to: new)
        } catch {
            return .failed
        }
        guard let outcome = await TimedProcess.run("/usr/bin/git", ["diff", "--no-index", "--no-color", "--no-ext-diff", "--unified=3", old.path, new.path],
                                                   timeout: .seconds(10)),
            outcome.status <= 1 else { return .failed }
        let lines = GitParsing.fileDiffs(fromUnified: String(decoding: outcome.stdout, as: UTF8.self)).values.first ?? []
        return lines.isEmpty ? .unchanged : .lines(lines)
    }

    private static func untrackedWithoutHead(_ top: URL) async -> String? {
        await GitCommand.run(["rev-parse", "--verify", "-q", "HEAD"], in: top) == nil ? "" : nil
    }
}
