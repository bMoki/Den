import Foundation

nonisolated enum SidebarOrder: String, Codable, CaseIterable, Sendable {
    case name, recent

    var label: String {
        switch self {
        case .name: "Nome"
        case .recent: "Criadas recentemente"
        }
    }
}

nonisolated enum SidebarGroup: String, Codable, Sendable {
    case favorites, branches, baseRepos, otherFolders

    var title: String {
        switch self {
        case .favorites: "Favoritos"
        case .branches: "Branches de workspace"
        case .baseRepos: "Repos base"
        case .otherFolders: "Outras pastas"
        }
    }
}

nonisolated struct SidebarFavorite: Codable, Hashable, Sendable {
    nonisolated enum Kind: String, Codable, Sendable {
        case branch, baseRepo, folder

        var group: String {
            switch self {
            case .branch: "branch"
            case .baseRepo: "base"
            case .folder: "other"
            }
        }
    }

    var kind: Kind
    var path: String
    var createdAt: Date?
}

nonisolated struct SidebarLayout: StoredInDefaults, Equatable, Sendable {
    static let key = "Den.sidebarLayout"

    var favorites: Set<SidebarFavorite> = []
    var order = SidebarOrder.name
    var collapsed: Set<SidebarGroup> = []

    init() {}

    init(favorites: Set<SidebarFavorite> = [], order: SidebarOrder = .name, collapsed: Set<SidebarGroup> = []) {
        self.favorites = favorites
        self.order = order
        self.collapsed = collapsed
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        favorites = try container.decodeIfPresent(Set<SidebarFavorite>.self, forKey: .favorites) ?? []
        order = try container.decodeIfPresent(SidebarOrder.self, forKey: .order) ?? .name
        collapsed = try container.decodeIfPresent(Set<SidebarGroup>.self, forKey: .collapsed) ?? []
    }

    func isExpanded(_ group: SidebarGroup, searching: Bool) -> Bool {
        searching || !collapsed.contains(group)
    }

    func shown(_ folders: [SidebarGroups.Folder], in group: SidebarGroup, focus: SidebarRow?,
               searching: Bool) -> [SidebarGroups.Folder] {
        isExpanded(group, searching: searching) ? folders : folders.filter { SidebarRow($0) == focus }
    }

    mutating func toggleCollapsed(_ group: SidebarGroup) {
        collapsed.toggle(group)
    }

    func isFavorite(_ favorite: SidebarFavorite) -> Bool {
        favorites.contains(favorite)
    }

    mutating func toggle(_ favorite: SidebarFavorite) {
        favorites.toggle(favorite)
    }

    func pruned(by status: NsStatus) -> SidebarLayout {
        let live = Dictionary(status.branches.map { ($0.path, $0.createdAt) }) { first, _ in first }
        var layout = self
        layout.favorites = Set(favorites.compactMap { favorite in
            guard favorite.kind == .branch else { return favorite }
            guard let createdAt = live[favorite.path] else { return nil }
            if favorite.createdAt == nil { return SidebarFavorite(kind: .branch, path: favorite.path, createdAt: createdAt) }
            return favorite.createdAt == createdAt ? favorite : nil
        })
        return layout
    }
}

nonisolated private extension Set {
    mutating func toggle(_ element: Element) {
        if remove(element) == nil { insert(element) }
    }
}
