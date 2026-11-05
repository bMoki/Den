import Foundation

nonisolated struct GitMarks: Equatable, Sendable {
    struct Repo {
        let root: URL
        let entries: [GitStatusEntry]
        let ignored: [String]
    }

    private(set) var states: [String: GitFileState] = [:]
    private(set) var folders: [String: GitFileState] = [:]
    private(set) var ignored: Set<String> = []

    func state(of node: FileNode) -> GitFileState? {
        node.isDirectory ? folders[node.id] : state(ofFile: node.url)
    }

    func state(ofFile url: URL) -> GitFileState? {
        states[url.path]
    }

    func isIgnoredItself(_ path: String) -> Bool {
        ignored.contains(path)
    }

    func isIgnored(_ path: String) -> Bool {
        var probe = path
        while !probe.isEmpty {
            if ignored.contains(probe) { return true }
            guard let slash = probe.lastIndex(of: "/") else { return false }
            probe = String(probe[..<slash])
        }
        return false
    }

    init() {}

    init(root: URL, repos: [Repo]) {
        let prefix = root.path + "/"
        for repo in repos {
            for entry in repo.entries where !entry.isDirectory {
                let path = repo.root.appending(path: entry.path).path
                states[path] = entry.state
                var folder = (path as NSString).deletingLastPathComponent
                while folder.hasPrefix(prefix) || folder == root.path {
                    folders[folder] = Self.folderState(folders[folder], adding: entry.state)
                    if folder == root.path { break }
                    folder = (folder as NSString).deletingLastPathComponent
                }
            }
            for path in repo.ignored {
                ignored.insert(repo.root.appending(path: path).path.trimmingSuffix("/"))
            }
        }
    }

    private static func folderState(_ current: GitFileState?, adding state: GitFileState) -> GitFileState {
        current == .modified || (state != .untracked && state != .added) ? .modified : .untracked
    }

    static func read(under root: URL) async -> GitMarks {
        var repos: [Repo] = []
        for repo in GitRepository.repoRoots(under: root) {
            let scope = root.path.hasPrefix(repo.path + "/") ? ["--", root.path] : []
            async let status = GitCommand.run(["--no-optional-locks", "status", "--porcelain=v1", "-z", "--untracked-files=all"] + scope, in: repo)
            async let ignored = GitCommand.run(
                ["--no-optional-locks", "status", "--porcelain=v1", "-z", "--ignored=traditional", "--untracked-files=normal"] + scope, in: repo)
            repos.append(Repo(root: repo, entries: GitParsing.statusEntries(fromPorcelain: await status ?? ""),
                              ignored: GitParsing.ignoredPaths(fromPorcelain: await ignored ?? "")))
        }
        return GitMarks(root: root, repos: repos)
    }
}

private extension String {
    nonisolated func trimmingSuffix(_ suffix: String) -> String {
        hasSuffix(suffix) ? String(dropLast(suffix.count)) : self
    }
}
