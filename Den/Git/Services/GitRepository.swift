import Foundation

nonisolated enum GitRepository {
    private static let maxRepos = 10

    private static let skippedFolders: Set<String> = [
        "node_modules", ".build", "DerivedData", ".next", "dist", "build",
        "Pods", ".venv", "vendor",
    ]

    static func repoRoots(under directory: URL) -> [URL] {
        let manager = FileManager.default
        var roots: [URL] = []

        if let toplevel = toplevel(containing: directory) {
            roots.append(toplevel)
        }

        func scan(_ dir: URL, depth: Int) {
            guard roots.count < maxRepos,
                  let children = try? manager.contentsOfDirectory(
                    at: dir, includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]) else { return }
            for child in children.sorted(by: { $0.path < $1.path }) {
                guard (try? child.resourceValues(forKeys: [.isDirectoryKey]))?
                    .isDirectory == true,
                      !skippedFolders.contains(child.lastPathComponent)
                else { continue }
                if manager.fileExists(atPath: child.appending(path: ".git").path) {
                    if roots.count < maxRepos { roots.append(child.standardizedFileURL) }
                } else if depth < 2 {
                    scan(child, depth: depth + 1)
                }
            }
        }
        scan(directory.standardizedFileURL, depth: 1)

        var seen: Set<String> = []
        return roots.filter { seen.insert($0.path).inserted }
    }

    static func toplevel(containing directory: URL) -> URL? {
        let manager = FileManager.default
        var probe = directory.standardizedFileURL
        while probe.pathComponents.count > 1 {
            if manager.fileExists(atPath: probe.appending(path: ".git").path) {
                return probe
            }
            probe = probe.deletingLastPathComponent()
        }
        return nil
    }

    static func gitDirectory(of toplevel: URL) -> URL {
        let marker = toplevel.standardizedFileURL.appending(path: ".git")
        guard !marker.isExistingDirectory,
              let text = try? String(contentsOf: marker, encoding: .utf8),
              let line = text.split(whereSeparator: \.isNewline)
                .first(where: { $0.hasPrefix("gitdir:") }) else { return marker }
        let gitdir = line.dropFirst("gitdir:".count).trimmingCharacters(in: .whitespaces)
        let absolute = gitdir.hasPrefix("/")
            ? URL(fileURLWithPath: gitdir) : marker.deletingLastPathComponent().appending(path: gitdir)
        return absolute.standardizedFileURL
    }

    static func mainCheckout(of toplevel: URL) -> URL {
        let checkout = toplevel.standardizedFileURL
        let path = gitDirectory(of: checkout).path
        guard let range = path.range(of: "/.git/worktrees/") else { return checkout }
        return URL(fileURLWithPath: String(path[..<range.lowerBound])).standardizedFileURL
    }
}
