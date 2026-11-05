import AppKit
import CodeEditLanguages
import CodeEditSourceEditor
import Foundation
import Observation

@MainActor
@Observable
final class EditorDocument: Identifiable {
    enum Mode { case code, preview, diff }

    nonisolated enum Kind: Equatable {
        case loading
        case text
        case image(Data)
        case unreadable(String)
    }

    let url: URL
    let language: CodeLanguage
    var text = ""
    var mode: Mode = .code
    var editorState = SourceEditorState()
    var problem: String?
    private(set) var saved = ""
    private(set) var kind: Kind = .loading
    private(set) var diff: FileDiff?
    @ObservationIgnored private var diffTask: Task<Void, Never>?

    init(url: URL) {
        self.url = url.standardizedFileURL
        language = CodeLanguage.detectLanguageFrom(url: url)
    }

    nonisolated var id: URL { url }
    var name: String { url.lastPathComponent }
    var isDirty: Bool { kind == .text && text != saved }
    var isMarkdown: Bool { ["md", "markdown"].contains(url.pathExtension.lowercased()) }

    func load() async {
        let url = url
        let contents = await Task.detached(priority: .userInitiated) { FileContents.read(url) }.value
        switch contents {
        case .text(let read):
            text = read
            saved = read
            kind = .text
        case .image(let data):
            kind = .image(data)
        case .unreadable(let reason):
            kind = .unreadable(reason)
        }
    }

    func save() {
        guard kind == .text else { return }
        guard url.deletingLastPathComponent().isExistingDirectory else {
            problem = "A pasta deste arquivo não existe mais."
            return
        }
        do {
            try Data(text.utf8).write(to: url)
            saved = text
            problem = nil
        } catch {
            problem = error.localizedDescription
        }
        if mode == .diff { loadDiff() }
    }

    func toggleFind() {
        if mode == .code, editorState.findPanelVisible == true {
            editorState.findPanelVisible = false
        } else {
            showFind()
        }
    }

    func showFind() {
        mode = .code
        editorState.findPanelVisible = true
    }

    func toggle(_ target: Mode) {
        mode = mode == target ? .code : target
        if mode == .diff { loadDiff() }
    }

    private func loadDiff() {
        diffTask?.cancel()
        let url = url
        let text = text
        diffTask = Task {
            let diff = await Task.detached(priority: .userInitiated) { await FileDiff.of(url, editing: text) }.value
            guard !Task.isCancelled else { return }
            self.diff = diff
        }
    }
}
