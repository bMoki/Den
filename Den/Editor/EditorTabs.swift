import Foundation
import Observation

@MainActor
@Observable
final class EditorTabs {
    private var open: [UUID: [EditorDocument]] = [:]
    private var selected: [UUID: URL] = [:]

    func documents(in session: UUID) -> [EditorDocument] {
        open[session] ?? []
    }

    func selection(in session: UUID) -> EditorDocument? {
        guard let url = selected[session] else { return nil }
        return documents(in: session).first { $0.url == url }
    }

    func open(_ url: URL, in session: UUID) {
        let url = url.standardizedFileURL
        let shared = open.values.lazy.flatMap(\.self).first { $0.url == url }
        let document = documents(in: session).first { $0.url == url } ?? shared.map { document in
            open[session, default: []].append(document)
            return document
        } ?? {
            let document = EditorDocument(url: url)
            open[session, default: []].append(document)
            Task { await document.load() }
            return document
        }()
        selected[session] = document.url
    }

    func select(_ document: EditorDocument?, in session: UUID) {
        selected[session] = document?.url
    }

    func close(_ document: EditorDocument, in session: UUID) {
        var documents = documents(in: session)
        guard let index = documents.firstIndex(where: { $0 === document }) else { return }
        documents.remove(at: index)
        open[session] = documents
        if selected[session] == document.url {
            selected[session] = documents.indices.contains(index) ? documents[index].url : documents.last?.url
        }
    }
}
