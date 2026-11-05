import AppKit
import CodeEditLanguages
import CodeEditSourceEditor
import Foundation
import Observation

@MainActor
@Observable
final class EditorDocument: Identifiable {
    enum Mode { case code, preview, diff, compare }

    nonisolated enum Kind: Equatable {
        case loading
        case text
        case image(Data)
        case unreadable(String)
    }

    nonisolated enum DiskLoss: Equatable {
        case deleted
        case unreadable(String)

        init?(_ contents: FileContents) {
            switch contents {
            case .missing: self = .deleted
            case .unreadable(let reason): self = .unreadable(reason)
            case .text, .image: return nil
            }
        }
    }

    let url: URL
    let language: CodeLanguage
    var text = ""
    var mode: Mode = .code
    var editorState = SourceEditorState()
    let memory = EditorMemory()
    var problem: String?
    private(set) var saved = ""
    private(set) var kind: Kind = .loading
    private(set) var changedOnDisk: String?
    private(set) var lostOnDisk: DiskLoss?
    private(set) var editorGeneration = 0
    private(set) var diff: FileDiff?
    @ObservationIgnored private var diffTask: Task<Void, Never>?
    @ObservationIgnored private var writes = 0

    init(url: URL) {
        self.url = url.standardizedFileURL
        language = CodeLanguage.detectLanguageFrom(url: url)
    }

    nonisolated var id: URL { url }
    var name: String { url.lastPathComponent }
    var isDirty: Bool { kind == .text && text != saved }
    var isMarkdown: Bool { ["md", "markdown"].contains(url.pathExtension.lowercased()) }

    func load() async {
        switch await readOffMain(limited: true) {
        case .text(let read):
            text = read
            saved = read
            kind = .text
        case .image(let data):
            kind = .image(data)
        case .unreadable(let reason):
            kind = .unreadable(reason)
        case .missing:
            kind = .unreadable("Este arquivo não existe mais.")
        }
    }

    func watch() async {
        let folder = url.deletingLastPathComponent()
        let changes = FolderWatcher.changes(in: folder)
        await readDisk()
        for await paths in changes where paths.contains(folder.path) || paths.contains(url.path) {
            await readDisk()
        }
    }

    func readDisk() async {
        let writesBefore = writes
        let contents = await readOffMain(limited: false)
        guard writes == writesBefore, kind == .text else { return }
        if let loss = DiskLoss(contents) {
            lose(loss)
        } else if case .text(let disk) = contents {
            lostOnDisk = nil
            absorbDiskChange(disk)
        }
    }

    func reloadFromDisk() {
        guard let changedOnDisk else { return }
        replace(with: changedOnDisk)
    }

    func compareWithDisk() {
        if changedOnDisk != nil { toggle(.compare) }
    }

    func keepMine() {
        guard let changedOnDisk else { return }
        saved = changedOnDisk
        clearConflict()
    }

    func save() {
        guard kind == .text, lostOnDisk == nil else { return }
        let contents = FileContents.read(url, limited: false)
        if let loss = DiskLoss(contents) {
            lose(loss)
        } else if case .text(let disk) = contents, changedOnDisk == nil, disk != saved, disk != text {
            changedOnDisk = disk
        } else {
            write()
        }
    }

    func saveAnyway() {
        guard lostOnDisk != nil else { return }
        write()
        if problem == nil { lostOnDisk = nil }
    }

    private func write() {
        guard url.deletingLastPathComponent().isExistingDirectory else {
            problem = "A pasta deste arquivo não existe mais."
            return
        }
        do {
            writes += 1
            try Data(text.utf8).write(to: url)
            saved = text
            clearConflict()
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

    private func readOffMain(limited: Bool) async -> FileContents {
        let url = url
        return await Task.detached(priority: .userInitiated) { FileContents.read(url, limited: limited) }.value
    }

    private func lose(_ loss: DiskLoss) {
        lostOnDisk = loss
        clearConflict()
    }

    private func absorbDiskChange(_ disk: String) {
        if disk == saved || disk == text {
            saved = disk
            clearConflict()
        } else if isDirty {
            changedOnDisk = disk
        } else {
            replace(with: disk)
        }
    }

    private func replace(with disk: String) {
        let old = text
        memory.recordReplacement(of: old, with: disk)
        memory.keep(editorState.scrollPosition)
        text = disk
        saved = disk
        editorState.cursorPositions = editorState.cursorPositions?.map { cursor in
            let moved = EditorMemory.moved(cursor.start, from: old, to: disk)
            return CursorPosition(line: moved.line, column: moved.column)
        }
        editorGeneration += 1
        clearConflict()
        if mode == .diff { loadDiff() }
    }

    private func clearConflict() {
        changedOnDisk = nil
        if mode == .compare { mode = .code }
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
