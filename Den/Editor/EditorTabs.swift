import Foundation
import Observation

nonisolated enum UnsavedChoice {
    case saveAll, discard, cancel
}

@MainActor
@Observable
final class EditorTabs {
    private var open: [SidebarRow: [EditorDocument]] = [:]
    private var selected: [SidebarRow: URL] = [:]
    @ObservationIgnored private let windows: EditorWindows

    init(windows: EditorWindows? = nil) {
        self.windows = windows ?? EditorWindows()
        self.windows.track(self)
    }

    var held: [(row: SidebarRow, document: EditorDocument)] {
        open.sorted { String(describing: $0.key) < String(describing: $1.key) }.flatMap { row, documents in
            documents.map { (row, $0) }
        }
    }

    var rows: Set<SidebarRow> {
        Set(open.keys)
    }

    func documents(in row: SidebarRow) -> [EditorDocument] {
        open[row] ?? []
    }

    func selection(in row: SidebarRow) -> EditorDocument? {
        guard let url = selected[row] else { return nil }
        return documents(in: row).first { $0.url == url }
    }

    func open(_ url: URL, in row: SidebarRow) {
        let url = url.standardizedFileURL
        let shared = windows.document(at: url)
        let document = documents(in: row).first { $0.url == url } ?? shared.map { document in
            open[row, default: []].append(document)
            return document
        } ?? {
            let document = EditorDocument(url: url)
            open[row, default: []].append(document)
            Task { await document.load() }
            return document
        }()
        selected[row] = document.url
    }

    func select(_ document: EditorDocument?, in row: SidebarRow) {
        selected[row] = document?.url
    }

    func unsaved(in row: SidebarRow? = nil) -> [EditorDocument] {
        windows.unsaved(in: row, window: self)
    }

    func settle(_ choice: UnsavedChoice, in row: SidebarRow? = nil) -> Bool {
        windows.settle(choice, in: row, window: self)
    }

    func close(_ row: SidebarRow) {
        open[row] = nil
        selected[row] = nil
    }

    func close(_ document: EditorDocument, in row: SidebarRow) {
        var documents = documents(in: row)
        guard let index = documents.firstIndex(where: { $0 === document }) else { return }
        documents.remove(at: index)
        open[row] = documents
        if selected[row] == document.url {
            selected[row] = documents.indices.contains(index) ? documents[index].url : documents.last?.url
        }
    }
}
