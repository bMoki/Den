import Foundation

nonisolated struct FileNode: Identifiable, Hashable, Sendable {
    let url: URL
    let isDirectory: Bool

    var id: String { url.path }
    var name: String { url.lastPathComponent }

    private static let hiddenNames: Set<String> = [".git", ".DS_Store"]

    static func children(of folder: URL) -> [FileNode]? {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return nil }
        return names.filter { !hiddenNames.contains($0) }
            .map { name in
                let url = folder.appending(path: name)
                return FileNode(url: url, isDirectory: url.isExistingDirectory)
            }
            .sorted { lhs, rhs in
                lhs.isDirectory != rhs.isDirectory
                    ? lhs.isDirectory
                    : lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }
}
