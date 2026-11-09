import Foundation
import HarnessCore

nonisolated enum SidebarRow: Hashable, Sendable {
    case branch(String)
    case baseRepo(String)
    case folder(String)
    case archived

    init(_ folder: SidebarGroups.Folder) {
        switch folder.kind {
        case .branch: self = .branch(folder.name)
        case .baseRepo: self = .baseRepo(folder.name)
        case .folder: self = .folder(folder.path.path)
        }
    }

    init(_ place: SessionPlace, directory: URL) {
        switch place {
        case .branch(let name): self = .branch(name)
        case .baseRepo(let repo): self = .baseRepo(repo)
        case .archived: self = .archived
        case .elsewhere: self = .folder(directory.standardizedFileURL.path)
        }
    }

    static let archivedTitle = "Arquivadas"

    var branch: String? {
        if case .branch(let name) = self { name } else { nil }
    }
}

extension WorkspaceModel {
    func groups(in ns: NsWorkspace, search: String = "") -> SidebarGroups {
        SidebarGroups(sessions: summaries, status: ns.status, search: search, layout: layout, place: ns.place(of:))
    }

    func closePageIfGone(from groups: SidebarGroups, statusKnown: Bool) {
        guard let page, page != .archived else { return }
        if case .folder = page {} else if !statusKnown { return }
        if groups.folder(page) == nil { self.page = nil }
    }
}

extension NsWorkspace {
    func row(of directory: URL) -> SidebarRow {
        SidebarRow(place(of: directory), directory: directory)
    }

    func title(of row: SidebarRow) -> String {
        switch row {
        case .branch(let name): branch(named: name)?.nickname ?? name
        case .baseRepo(let repo): repo
        case .folder(let path): URL(fileURLWithPath: path).lastPathComponent
        case .archived: SidebarRow.archivedTitle
        }
    }
}
