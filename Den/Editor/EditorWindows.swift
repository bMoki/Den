import Foundation

@MainActor
final class EditorWindows {
    static let shared = EditorWindows()

    private let windows = NSHashTable<EditorTabs>.weakObjects()

    func track(_ tabs: EditorTabs) {
        windows.add(tabs)
    }

    func unsaved(in session: UUID? = nil) -> [EditorDocument] {
        windows.allObjects.flatMap { $0.unsaved(in: session) }
    }

    func settle(_ choice: UnsavedChoice, in session: UUID? = nil) -> Bool {
        choice != .cancel && windows.allObjects.map { $0.settle(choice, in: session) }.allSatisfy(\.self)
    }

    func closeSession(_ session: UUID) {
        windows.allObjects.forEach { $0.closeSession(session) }
    }
}
