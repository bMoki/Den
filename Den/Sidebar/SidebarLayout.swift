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

    init() {}

    init(favorites: Set<SidebarFavorite> = [], order: SidebarOrder = .name) {
        self.favorites = favorites
        self.order = order
    }

    func isFavorite(_ favorite: SidebarFavorite) -> Bool {
        favorites.contains(favorite)
    }

    mutating func toggle(_ favorite: SidebarFavorite) {
        if favorites.remove(favorite) == nil { favorites.insert(favorite) }
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
