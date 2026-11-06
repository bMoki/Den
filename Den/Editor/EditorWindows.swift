import Foundation

@MainActor
final class EditorWindows {
    static let shared = EditorWindows()

    private struct Place {
        let tabs: EditorTabs
        let session: UUID
        let document: EditorDocument
    }

    private let windows = NSHashTable<EditorTabs>.weakObjects()

    func track(_ tabs: EditorTabs) {
        windows.add(tabs)
    }

    func document(at url: URL) -> EditorDocument? {
        places.first { $0.document.url == url }?.document
    }

    func unsaved(in session: UUID? = nil, window: EditorTabs? = nil) -> [EditorDocument] {
        let inside = Self.inside(session, window)
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

    func settle(_ choice: UnsavedChoice, in session: UUID? = nil, window: EditorTabs? = nil) -> Bool {
        switch choice {
        case .cancel:
            return false
        case .discard:
            return true
        case .saveAll:
            let unsaved = unsaved(in: session, window: window)
            unsaved.filter { $0.changedOnDisk == nil }.forEach { $0.save() }
            guard let failed = unsaved.first(where: \.isDirty) else { return true }
            let inside = Self.inside(session, window)
            if let place = places.first(where: { inside($0) && $0.document === failed }) {
                place.tabs.select(failed, in: place.session)
            }
            return false
        }
    }

    func closeSession(_ session: UUID) {
        windows.allObjects.forEach { $0.closeSession(session) }
    }

    private var places: [Place] {
        windows.allObjects.flatMap { tabs in
            tabs.held.map { Place(tabs: tabs, session: $0.session, document: $0.document) }
        }
    }

    private static func inside(_ session: UUID?, _ window: EditorTabs?) -> (Place) -> Bool {
        { place in (session.map { $0 == place.session } ?? true) && (window.map { $0 === place.tabs } ?? true) }
    }
}
