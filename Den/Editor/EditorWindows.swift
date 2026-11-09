import Foundation

@MainActor
final class EditorWindows {
    static let shared = EditorWindows()

    private struct Place {
        let tabs: EditorTabs
        let row: SidebarRow
        let document: EditorDocument
    }

    private let windows = NSHashTable<EditorTabs>.weakObjects()

    func track(_ tabs: EditorTabs) {
        windows.add(tabs)
    }

    func document(at url: URL) -> EditorDocument? {
        places.first { $0.document.url == url }?.document
    }

    func unsaved(in row: SidebarRow? = nil, window: EditorTabs? = nil) -> [EditorDocument] {
        let inside = Self.inside(row, window)
        let elsewhere = places.filter { !inside($0) }.map(\.document)
        var found: [EditorDocument] = []
        for place in places where inside(place) && place.document.isDirty {
            let document = place.document
            if !found.contains(where: { $0 === document }), !elsewhere.contains(where: { $0 === document }) {
                found.append(document)
            }
        }
        return found
    }

    func settle(_ choice: UnsavedChoice, in row: SidebarRow? = nil, window: EditorTabs? = nil) -> Bool {
        switch choice {
        case .cancel:
            return false
        case .discard:
            return true
        case .saveAll:
            let unsaved = unsaved(in: row, window: window)
            unsaved.filter { $0.changedOnDisk == nil }.forEach { $0.save() }
            guard let failed = unsaved.first(where: \.isDirty) else { return true }
            let inside = Self.inside(row, window)
            if let place = places.first(where: { inside($0) && $0.document === failed }) {
                place.tabs.select(failed, in: place.row)
            }
            return false
        }
    }

    func close(_ row: SidebarRow) {
        windows.allObjects.forEach { $0.close(row) }
    }

    private var places: [Place] {
        windows.allObjects.flatMap { tabs in
            tabs.held.map { Place(tabs: tabs, row: $0.row, document: $0.document) }
        }
    }

    private static func inside(_ row: SidebarRow?, _ window: EditorTabs?) -> (Place) -> Bool {
        { place in (row.map { $0 == place.row } ?? true) && (window.map { $0 === place.tabs } ?? true) }
    }
}
