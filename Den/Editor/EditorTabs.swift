import Foundation
import Observation

nonisolated enum UnsavedChoice {
    case saveAll, discard, cancel
}

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

    func unsaved(in session: UUID? = nil) -> [EditorDocument] {
        guard let session else {
            var seen: Set<ObjectIdentifier> = []
            return open.values.flatMap(\.self).filter { $0.isDirty && seen.insert(ObjectIdentifier($0)).inserted }
        }
        let elsewhere = open.filter { $0.key != session }.values.flatMap(\.self)
        return documents(in: session).filter { document in document.isDirty && !elsewhere.contains { $0 === document } }
    }

    func settle(_ choice: UnsavedChoice, in session: UUID? = nil) -> Bool {
        switch choice {
        case .cancel:
            return false
        case .discard:
            return true
        case .saveAll:
            let unsaved = unsaved(in: session)
            unsaved.filter { $0.changedOnDisk == nil }.forEach { $0.save() }
            guard let failed = unsaved.first(where: \.isDirty) else { return true }
            if let owner = session ?? open.first(where: { $0.value.contains { $0 === failed } })?.key {
                selected[owner] = failed.url
            }
            return false
        }
    }

    func closeSession(_ session: UUID) {
        open[session] = nil
        selected[session] = nil
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
