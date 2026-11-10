import SwiftUI

enum ThalamusMenuIcon {
    case symbol(String, Color)
    case image(Image)
}

struct ThalamusMenuItem: Identifiable {
    let id: String
    var title: String
    var icon: ThalamusMenuIcon?
    var isSelected: Bool
    var isEnabled: Bool
    var isDestructive: Bool
    var shortcut: String?
    var children: [ThalamusMenuSection]
    var action: () -> Void

    init(id: String,
         title: String,
         icon: ThalamusMenuIcon? = nil,
         isSelected: Bool = false,
         isEnabled: Bool = true,
         isDestructive: Bool = false,
         shortcut: String? = nil,
         children: [ThalamusMenuSection] = [],
         action: @escaping () -> Void = {}) {
        self.id = id
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.isEnabled = isEnabled
        self.isDestructive = isDestructive
        self.shortcut = shortcut
        self.children = children
        self.action = action
    }
}

struct ThalamusMenuSection: Identifiable {
    let id: String
    var header: String?
    var items: [ThalamusMenuItem]

    init(id: String = "main", header: String? = nil, items: [ThalamusMenuItem]) {
        self.id = id
        self.header = header
        self.items = items
    }

    static func showsIcons(in sections: [ThalamusMenuSection]) -> Bool {
        sections.contains { $0.items.contains { $0.icon != nil } }
    }
}
