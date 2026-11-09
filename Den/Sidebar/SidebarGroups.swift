import Foundation
import HarnessCore

nonisolated struct SidebarGroups: Equatable {
    nonisolated struct Folder: Identifiable, Equatable {
        let id: String
        var name: String
        var nickname: String?
        var sessions: [SessionSummary]
        let favorite: SidebarFavorite

        var kind: SidebarFavorite.Kind { favorite.kind }
        var path: URL { URL(fileURLWithPath: favorite.path) }

        init(_ kind: SidebarFavorite.Kind, name: String, nickname: String? = nil, path: String,
             createdAt: Date? = nil, sessions: [SessionSummary]) {
            id = kind.group + ":" + URL(fileURLWithPath: path).path
            self.name = name
            self.nickname = nickname
            self.sessions = sessions
            favorite = SidebarFavorite(kind: kind, path: path, createdAt: createdAt)
        }
    }

    var favorites: [Folder] = []
    var branches: [Folder] = []
    var baseRepos: [Folder] = []
    var otherFolders: [Folder] = []
    var archived: [SessionSummary] = []

    var folders: [Folder] { favorites + branches + baseRepos + otherFolders }

    func folder(_ row: SidebarRow) -> Folder? {
        folders.first { SidebarRow($0) == row }
    }

    var isEmpty: Bool {
        favorites.isEmpty && branches.isEmpty && baseRepos.isEmpty && otherFolders.isEmpty && archived.isEmpty
    }

    init(sessions: [SessionSummary], status: NsStatus?, search: String = "",
         layout: SidebarLayout = SidebarLayout(), place: ((URL) -> SessionPlace)? = nil) {
        let place = place ?? { status?.place(of: $0) ?? .elsewhere }
        let matching = sessions
            .filter { search.isEmpty || Self.session($0, matches: search) }
            .sorted { $0.updatedAt > $1.updatedAt }
        var branchSessions: [String: [SessionSummary]] = [:]
        var baseSessions: [String: [SessionSummary]] = [:]
        var elsewhere: [SessionSummary] = []
        for session in matching {
            switch place(session.workingDirectory) {
            case .branch(let name): branchSessions[name, default: []].append(session)
            case .baseRepo(let repo): baseSessions[repo, default: []].append(session)
            case .archived: archived.append(session)
            case .elsewhere: elsewhere.append(session)
            }
        }

        let keep = { (folder: Folder) in
            search.isEmpty || !folder.sessions.isEmpty || folder.name.localizedCaseInsensitiveContains(search)
                || BranchNickname.matches(folder.nickname, search)
        }
        let branchFolders = (status?.branches ?? []).map {
            Folder(.branch, name: $0.branch, nickname: $0.nickname, path: $0.path, createdAt: $0.createdAt,
                   sessions: branchSessions[$0.branch] ?? [])
        }
        let baseFolders = (status?.baseRepos ?? []).map {
            Folder(.baseRepo, name: $0.repo, path: $0.path, sessions: baseSessions[$0.repo] ?? [])
        }
        let elsewhereFolders = Dictionary(grouping: elsewhere) { $0.workingDirectory.standardizedFileURL.path }
            .map { Folder(.folder, name: URL(fileURLWithPath: $0.key).lastPathComponent, path: $0.key, sessions: $0.value) }
            .sorted { ($0.sessions[0].updatedAt, $1.id) > ($1.sessions[0].updatedAt, $0.id) }

        let isFavorite = { (folder: Folder) in layout.isFavorite(folder.favorite) }
        favorites = Self.sorted((branchFolders + baseFolders + elsewhereFolders).filter(isFavorite),
                                by: layout.order).filter(keep)
        branches = Self.sorted(branchFolders.filter { !isFavorite($0) }, by: layout.order).filter(keep)
        baseRepos = baseFolders.filter { !isFavorite($0) }.filter(keep)
        otherFolders = elsewhereFolders.filter { !isFavorite($0) }
    }

    subscript(group: SidebarGroup) -> [Folder] {
        switch group {
        case .favorites: favorites
        case .branches: branches
        case .baseRepos: baseRepos
        case .otherFolders: otherFolders
        }
    }

    static func sorted(_ folders: [Folder], by order: SidebarOrder) -> [Folder] {
        let byName = { (lhs: Folder, rhs: Folder) in
            switch lhs.name.localizedStandardCompare(rhs.name) {
            case .orderedAscending: true
            case .orderedDescending: false
            case .orderedSame: lhs.id < rhs.id
            }
        }
        guard order == .recent else { return folders.sorted(by: byName) }
        return folders.sorted { lhs, rhs in
            let (left, right) = (lhs.kind == .branch, rhs.kind == .branch)
            if left != right { return left }
            let (newer, older) = (lhs.favorite.createdAt ?? .distantPast, rhs.favorite.createdAt ?? .distantPast)
            return newer == older ? byName(lhs, rhs) : newer > older
        }
    }

    private static func session(_ session: SessionSummary, matches search: String) -> Bool {
        session.title.localizedCaseInsensitiveContains(search)
            || session.workingDirectory.lastPathComponent.localizedCaseInsensitiveContains(search)
    }
}
