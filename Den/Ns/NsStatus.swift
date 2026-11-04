import Foundation

nonisolated struct NsStatus: Decodable, Equatable, Sendable {
    nonisolated struct BaseRepo: Decodable, Equatable, Sendable {
        var repo: String
        var path: String
    }

    nonisolated struct Branch: Decodable, Equatable, Sendable {
        var branch: String
        var path: String
    }

    var baseRepos: [BaseRepo]
    var branches: [Branch]

    func place(of directory: URL) -> SessionPlace {
        let path = directory.standardizedFileURL.path
        if let branch = branches.first(where: { Self.path(path, isInside: $0.path) }) {
            return .branch(branch.branch)
        }
        if let base = baseRepos.first(where: { Self.path(path, isInside: $0.path) }) {
            return .baseRepo(base.repo)
        }
        return .elsewhere
    }

    private static func path(_ path: String, isInside folder: String) -> Bool {
        let root = URL(fileURLWithPath: folder).standardizedFileURL.path
        return path == root || path.hasPrefix(root + "/")
    }
}

nonisolated enum SessionPlace: Hashable, Sendable {
    case branch(String)
    case baseRepo(String)
    case elsewhere
}
