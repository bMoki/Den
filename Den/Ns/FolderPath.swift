import Foundation

nonisolated enum FolderPath {
    static func canonical(_ path: String) -> String {
        var existing = URL(fileURLWithPath: path).standardizedFileURL
        var missing: [String] = []
        while existing.path != "/", !FileManager.default.fileExists(atPath: existing.path) {
            missing.insert(existing.lastPathComponent, at: 0)
            existing = existing.deletingLastPathComponent()
        }
        return missing.reduce(existing.resolvingSymlinksInPath()) { $0.appending(path: $1) }.path
    }

    static func path(_ path: String, isInside folder: String) -> Bool {
        let root = canonical(folder)
        return path == root || path.hasPrefix(root + "/")
    }
}
