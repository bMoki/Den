import Foundation
import HarnessCore

nonisolated struct SidebarGroups: Equatable {
    nonisolated struct Folder: Identifiable, Equatable {
        let id: String
        var name: String
        var path: URL
        var sessions: [SessionSummary]

        init(group: String, name: String, path: URL, sessions: [SessionSummary]) {
            id = group + ":" + path.path
            self.name = name
            self.path = path
            self.sessions = sessions
        }
    }

    var branches: [Folder] = []
    var baseRepos: [Folder] = []
    var otherFolders: [Folder] = []

    var isEmpty: Bool {
        branches.isEmpty && baseRepos.isEmpty && otherFolders.isEmpty
    }

    init(sessions: [SessionSummary], status: NsStatus?, search: String = "") {
        let matching = sessions
            .filter { search.isEmpty || Self.session($0, matches: search) }
            .sorted { $0.updatedAt > $1.updatedAt }
        var branchSessions: [String: [SessionSummary]] = [:]
        var baseSessions: [String: [SessionSummary]] = [:]
        var elsewhere: [SessionSummary] = []
        for session in matching {
            switch status?.place(of: session.workingDirectory) ?? .elsewhere {
            case .branch(let name): branchSessions[name, default: []].append(session)
            case .baseRepo(let repo): baseSessions[repo, default: []].append(session)
            case .elsewhere: elsewhere.append(session)
            }
        }

        let keep = { (folder: Folder) in
            search.isEmpty || !folder.sessions.isEmpty || folder.name.localizedCaseInsensitiveContains(search)
        }
        branches = (status?.branches ?? []).map {
            Folder(group: "branch", name: $0.branch, path: URL(fileURLWithPath: $0.path), sessions: branchSessions[$0.branch] ?? [])
        }.filter(keep)
        baseRepos = (status?.baseRepos ?? []).map {
            Folder(group: "base", name: $0.repo, path: URL(fileURLWithPath: $0.path), sessions: baseSessions[$0.repo] ?? [])
        }.filter(keep)
        otherFolders = Dictionary(grouping: elsewhere) { $0.workingDirectory.standardizedFileURL.path }
            .map { Folder(group: "other", name: URL(fileURLWithPath: $0.key).lastPathComponent,
                          path: URL(fileURLWithPath: $0.key), sessions: $0.value) }
            .sorted { ($0.sessions[0].updatedAt, $1.id) > ($1.sessions[0].updatedAt, $0.id) }
    }

    private static func session(_ session: SessionSummary, matches search: String) -> Bool {
        session.title.localizedCaseInsensitiveContains(search)
            || session.workingDirectory.lastPathComponent.localizedCaseInsensitiveContains(search)
    }
}
