import Foundation

nonisolated struct NsMemory: StoredInDefaults, Equatable, Sendable {
    static let key = PreferenceKey.named("nsMemory")

    var worktreesDir: String?
    var branches: [String: String] = [:]

    init() {}

    init(worktreesDir: String? = nil, branches: [String: String] = [:]) {
        self.worktreesDir = worktreesDir
        self.branches = branches
    }

    func learned(from status: NsStatus) -> NsMemory {
        let worktreesDir = status.worktreesDir ?? worktreesDir
        let live = Dictionary(status.branches.map { ($0.branch, $0.path) }) { first, _ in first }
        let removedElsewhere = branches.filter { name, path in
            live[name] == nil && !(worktreesDir.map { FolderPath.path(FolderPath.canonical(path), isInside: $0) } ?? false)
        }
        return NsMemory(worktreesDir: worktreesDir, branches: removedElsewhere.merging(live) { $1 })
    }

    func place(of directory: URL, in status: NsStatus?) -> SessionPlace {
        let status = status ?? NsStatus(worktreesDir: nil, baseRepos: [], branches: [])
        let place = status.place(of: directory, worktreesDir: worktreesDir)
        switch place {
        case .branch, .baseRepo: return place
        case .archived, .elsewhere: break
        }
        let path = FolderPath.canonical(directory.path)
        let remembered = branches
            .filter { name, root in status.branch(named: name) == nil && FolderPath.path(path, isInside: root) }
            .max { ($0.value.count, $0.key) < ($1.value.count, $1.key) }
        guard let remembered else { return place }
        return FileManager.default.fileExists(atPath: remembered.value) ? .elsewhere : .archived(remembered.key)
    }
}
