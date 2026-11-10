import AppKit

@MainActor
enum UnsavedAlert {
    static func confirm(_ question: String, unsaved: [EditorDocument], settle: (UnsavedChoice) -> Bool) -> Bool {
        guard !unsaved.isEmpty else { return true }
        let choice = ask(question, about: unsaved)
        guard !settle(choice) else { return true }
        if choice == .saveAll { tellFailure(unsaved.filter(\.isDirty)) }
        return false
    }

    static func listing(_ documents: [EditorDocument]) -> String {
        let names = documents.map(\.name).sorted()
        guard names.count > 1 else { return "\(names[0]) tem alterações não salvas." }
        return "\(names.count) arquivos têm alterações não salvas: \(names.joined(separator: ", "))."
    }

    private static func ask(_ question: String, about documents: [EditorDocument]) -> UnsavedChoice {
        let alert = NSAlert()
        alert.messageText = question
        alert.informativeText = "\(listing(documents)) Descartar perde essas alterações."
        alert.addButton(withTitle: "Salvar tudo")
        alert.addButton(withTitle: "Descartar").hasDestructiveAction = true
        alert.addButton(withTitle: "Cancelar").keyEquivalent = "\u{1b}"
        switch alert.runModal() {
        case .alertFirstButtonReturn: return .saveAll
        case .alertSecondButtonReturn: return .discard
        default: return .cancel
        }
    }

    static func tellFailure(_ documents: [EditorDocument]) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Não consegui salvar tudo."
        alert.informativeText = "\(listing(documents)) O aviso está no editor."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
