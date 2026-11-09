import CodeEditSourceEditor
import CodeEditTextView
import Foundation
import Testing
@testable import Den

private func file(_ name: String, _ contents: Data, in folder: URL) throws -> URL {
    let url = folder.appending(path: name)
    try contents.write(to: url)
    return url
}

private func repo(committing name: String, _ text: String) async throws -> URL {
    let root = try makeTree([])
    try await git(["init", "-q", "-b", "main"], in: root)
    _ = try file(name, Data(text.utf8), in: root)
    try await git(["add", "."], in: root)
    try await git(["commit", "-q", "-m", "initial"], in: root)
    return root
}

@Test func filesAreReadAsTextImagesOrNotAtAll() throws {
    let root = try makeTree([])
    defer { try? FileManager.default.removeItem(at: root) }

    #expect(FileContents.read(try file("Main.java", Data("class Main {}\n".utf8), in: root)) == .text("class Main {}\n"))
    #expect(FileContents.read(try file("logo.png", Data([0x89, 0x50, 0x4E, 0x47]), in: root)) == .image(Data([0x89, 0x50, 0x4E, 0x47])))
    #expect(FileContents.read(try file("app.bin", Data([0x41, 0x00, 0x42]), in: root)) == .unreadable("Arquivo binário."))
    #expect(FileContents.read(try file("latin.txt", Data([0x63, 0xE3, 0x6F]), in: root)) == .unreadable("Este arquivo não está em UTF-8."))
    #expect(FileContents.read(root.appending(path: "missing.txt")) == .missing)
    let large = try file("dump.sql", Data(count: FileContents.sizeLimit + 1), in: root)
    guard case .unreadable(let reason) = FileContents.read(large) else {
        Issue.record("a file over the limit should not open")
        return
    }
    #expect(reason.hasPrefix("Arquivo grande demais"))
}

@Test @MainActor func savingWritesTheEditorTextAndKeepsTheFilePermissions() async throws {
    let root = try makeTree([])
    defer { try? FileManager.default.removeItem(at: root) }
    let script = try file("mvnw", Data("echo old\n".utf8), in: root)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)

    let document = EditorDocument(url: script)
    await document.load()
    #expect(document.text == "echo old\n")
    #expect(!document.isDirty)

    document.text = "echo new\n"
    #expect(document.isDirty)
    document.save()

    #expect(!document.isDirty)
    #expect(document.problem == nil)
    #expect(try String(contentsOf: script, encoding: .utf8) == "echo new\n")
    let permissions = try FileManager.default.attributesOfItem(atPath: script.path)[.posixPermissions] as? Int
    #expect(permissions == 0o755)
}

@Test @MainActor func savingAFileThatCannotBeWrittenReportsIt() async throws {
    let root = try makeTree([])
    defer { try? FileManager.default.removeItem(at: root) }
    let locked = try file("locked.txt", Data("a".utf8), in: root)
    let document = EditorDocument(url: locked)
    await document.load()
    try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: locked.path)

    document.text = "b"
    document.save()

    #expect(document.isDirty)
    #expect(document.problem != nil)
}

@Test func theDiffComparesTheEditorTextWithTheLastCommit() async throws {
    let root = try await repo(committing: "Guia.java", "a\nb\nc\n")
    defer { try? FileManager.default.removeItem(at: root) }
    let url = root.appending(path: "Guia.java")

    #expect(await FileDiff.of(url, editing: "a\nb\nc\n") == .unchanged)

    guard case .lines(let lines) = await FileDiff.of(url, editing: "a\nB\nc\n") else {
        Issue.record("an edited text should have a diff")
        return
    }
    #expect(lines.filter { $0.kind == .removed }.map(\.text) == ["b"])
    #expect(lines.filter { $0.kind == .added }.map(\.text) == ["B"])
    #expect(lines.first { $0.kind == .added }?.number == 2)
}

@Test func aFileTheRepoDoesNotTrackDiffsAsAllNew() async throws {
    let root = try await repo(committing: "README.md", "x\n")
    defer { try? FileManager.default.removeItem(at: root) }

    guard case .lines(let lines) = await FileDiff.of(root.appending(path: "novo.sql"), editing: "select 1;\n") else {
        Issue.record("a new file should diff as added")
        return
    }
    #expect(lines.filter { $0.kind != .hunk }.map(\.kind) == [.added])
}

@Test func aFileOutsideGitHasNoDiff() async throws {
    let root = try makeTree([])
    defer { try? FileManager.default.removeItem(at: root) }

    #expect(await FileDiff.of(root.appending(path: "notes.md"), editing: "x") == .outsideGit)
}

@Test @MainActor func tabsBelongToTheirSessionAndOpenEachFileOnce() throws {
    let root = try makeTree([], files: ["a.ts", "b.yaml"])
    defer { try? FileManager.default.removeItem(at: root) }
    let tabs = EditorTabs()
    let row = anyRow()
    let other = anyRow()

    tabs.open(root.appending(path: "a.ts"), in: row)
    tabs.open(root.appending(path: "b.yaml"), in: row)
    tabs.open(root.appending(path: "a.ts"), in: row)

    #expect(tabs.documents(in: row).map(\.name) == ["a.ts", "b.yaml"])
    #expect(tabs.selection(in: row)?.name == "a.ts")
    #expect(tabs.documents(in: other).isEmpty)
    #expect(tabs.selection(in: other) == nil)

    tabs.select(nil, in: row)
    #expect(tabs.selection(in: row) == nil)
}

@Test @MainActor func closingTheShownTabShowsTheNextOneOrTheSession() throws {
    let root = try makeTree([], files: ["a.ts", "b.ts", "c.ts"])
    defer { try? FileManager.default.removeItem(at: root) }
    let tabs = EditorTabs()
    let row = anyRow()
    for name in ["a.ts", "b.ts", "c.ts"] { tabs.open(root.appending(path: name), in: row) }
    let documents = tabs.documents(in: row)

    tabs.select(documents[1], in: row)
    tabs.close(documents[1], in: row)
    #expect(tabs.selection(in: row)?.name == "c.ts")

    tabs.close(documents[2], in: row)
    #expect(tabs.selection(in: row)?.name == "a.ts")

    tabs.close(documents[0], in: row)
    #expect(tabs.selection(in: row) == nil)
    #expect(tabs.documents(in: row).isEmpty)
}

@Test @MainActor func modesToggleBackToTheCode() async throws {
    let root = try makeTree([], files: ["README.md"])
    defer { try? FileManager.default.removeItem(at: root) }
    let document = EditorDocument(url: root.appending(path: "README.md"))
    await document.load()

    #expect(document.isMarkdown)
    document.toggle(.preview)
    #expect(document.mode == .preview)
    document.toggleFind()
    #expect(document.mode == .code)
    #expect(document.editorState.findPanelVisible == true)
    document.toggle(.diff)
    document.toggle(.diff)
    #expect(document.mode == .code)
}

@Test @MainActor func aFileOpenInTwoSessionsSharesOneBuffer() throws {
    let root = try makeTree([], files: ["a.ts"])
    defer { try? FileManager.default.removeItem(at: root) }
    let tabs = EditorTabs()
    let first = anyRow()
    let second = anyRow()

    tabs.open(root.appending(path: "a.ts"), in: first)
    tabs.open(root.appending(path: "a.ts"), in: second)

    #expect(tabs.selection(in: first) === tabs.selection(in: second))
}

@Test @MainActor func savingIntoAFolderThatIsGoneSaysSo() async throws {
    let root = try makeTree(["gone"], files: ["gone/a.txt"])
    defer { try? FileManager.default.removeItem(at: root) }
    let document = EditorDocument(url: root.appending(path: "gone/a.txt"))
    await document.load()
    try FileManager.default.removeItem(at: root.appending(path: "gone"))

    document.text = "x"
    document.save()
    #expect(document.lostOnDisk == .deleted)
    document.saveAnyway()

    #expect(document.problem == "A pasta deste arquivo não existe mais.")
    #expect(document.lostOnDisk == .deleted)
    #expect(!FileManager.default.fileExists(atPath: root.appending(path: "gone").path))
}

@Test func largeImagesStillOpenAsImages() throws {
    let root = try makeTree([])
    defer { try? FileManager.default.removeItem(at: root) }
    let shot = try file("retina.png", Data(count: FileContents.sizeLimit + 1), in: root)

    #expect(FileContents.read(shot) == .image(Data(count: FileContents.sizeLimit + 1)))
}

@Test func aFileStagedInARepoWithoutCommitsDiffsAsAllNew() async throws {
    let root = try makeTree([])
    defer { try? FileManager.default.removeItem(at: root) }
    try await git(["init", "-q", "-b", "main"], in: root)

    guard case .lines(let lines) = await FileDiff.of(root.appending(path: "a.sql"), editing: "select 1;\n") else {
        Issue.record("a repo without commits should diff the file as new")
        return
    }
    #expect(lines.filter { $0.kind != .hunk }.map(\.kind) == [.added])
}

@MainActor
private func opened(_ text: String) async throws -> (EditorDocument, URL) {
    let source = try file("Main.java", Data(text.utf8), in: try makeTree([]))
    let document = EditorDocument(url: source)
    await document.load()
    return (document, source)
}

@MainActor
private func conflicted() async throws -> (EditorDocument, URL) {
    let (document, source) = try await opened("a\n")
    document.text = "mine\n"
    try Data("agent\n".utf8).write(to: source)
    await document.readDisk()
    return (document, source)
}

@Test @MainActor func aChangeOnDiskReplacesTheTextWhenNothingIsUnsaved() async throws {
    let (document, source) = try await opened("class Main {}\n")
    defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

    try Data("class Main { int a; }\n".utf8).write(to: source)
    await document.readDisk()

    #expect(document.text == "class Main { int a; }\n")
    #expect(!document.isDirty)
    #expect(document.changedOnDisk == nil)
    #expect(document.editorGeneration == 1)
}

@Test @MainActor func ourOwnSaveIsNotTakenForAChangeOnDisk() async throws {
    let (document, source) = try await opened("a\n")
    defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

    document.text = "b\n"
    document.save()
    await document.readDisk()

    #expect(document.changedOnDisk == nil)
    #expect(document.editorGeneration == 0)
}

@Test @MainActor func aChangeOnDiskOverUnsavedTextAsksAndReloadTakesTheDisk() async throws {
    let (document, source) = try await conflicted()
    defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

    #expect(document.text == "mine\n")
    #expect(document.changedOnDisk == "agent\n")
    document.reloadFromDisk()
    #expect(document.text == "agent\n")
    #expect(!document.isDirty)
    #expect(document.changedOnDisk == nil)
}

@Test @MainActor func compareShowsBothVersionsUntilTheConflictIsSettled() async throws {
    let (document, source) = try await conflicted()
    defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

    document.compareWithDisk()
    #expect(document.mode == .compare)
    #expect(document.text == "mine\n")
    #expect(document.changedOnDisk == "agent\n")
    document.keepMine()
    #expect(document.mode == .code)
    document.compareWithDisk()
    #expect(document.mode == .code)
}

@Test @MainActor func keepingMineMakesTheNextSaveOverwriteTheDisk() async throws {
    let (document, source) = try await conflicted()
    defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

    document.keepMine()
    #expect(document.changedOnDisk == nil)
    #expect(document.isDirty)
    await document.readDisk()
    #expect(document.changedOnDisk == nil)
    document.save()

    #expect(try String(contentsOf: source, encoding: .utf8) == "mine\n")
    #expect(!document.isDirty)
}

@Test @MainActor func savingWhileWarnedKeepsMineOnDisk() async throws {
    let (document, source) = try await conflicted()
    defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

    document.save()

    #expect(document.changedOnDisk == nil)
    #expect(try String(contentsOf: source, encoding: .utf8) == "mine\n")
}

@Test @MainActor func savingOverAChangeTheWatcherHasNotSeenYetAsksFirst() async throws {
    let (document, source) = try await opened("a\n")
    defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
    document.text = "mine\n"
    try Data("agent\n".utf8).write(to: source)

    document.save()

    #expect(document.changedOnDisk == "agent\n")
    #expect(try String(contentsOf: source, encoding: .utf8) == "agent\n")
}

@Test @MainActor func theWatcherPicksUpAnAgentWrite() async throws {
    let (document, source) = try await opened("a\n")
    defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
    let watching = Task { await document.watch() }
    defer { watching.cancel() }
    try await Task.sleep(for: .milliseconds(300))

    try Data("agent\n".utf8).write(to: source)
    for _ in 0..<50 where document.text != "agent\n" {
        try await Task.sleep(for: .milliseconds(100))
    }

    #expect(document.text == "agent\n")
}

@MainActor
private func shown(_ document: EditorDocument) -> TextView {
    let view = TextView(string: document.text)
    view.setUndoManager(document.memory.undoManager)
    return view
}

@Test @MainActor func undoOutlivesTheEditorViewItWasTypedIn() async throws {
    let (document, source) = try await opened("class Main {}\n")
    defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

    let first = shown(document)
    first.replaceCharacters(in: [NSRange(location: 12, length: 0)], with: " int a; ")
    document.text = first.string

    let second = shown(document)
    document.memory.undoManager.undo()
    #expect(second.string == "class Main {}\n")
}

@Test @MainActor func aReloadFromDiskKeepsTheCursorAndCanBeUndone() async throws {
    let (document, source) = try await opened("line one\nline two\n")
    defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
    document.editorState.cursorPositions = [CursorPosition(line: 2, column: 5)]

    try Data("new first line\nline one\nline two\n".utf8).write(to: source)
    await document.readDisk()

    #expect(document.text == "new first line\nline one\nline two\n")
    #expect(document.editorState.cursorPositions?.map(\.start) == [CursorPosition.Position(line: 3, column: 5)])
    let view = shown(document)
    document.memory.undoManager.undo()
    #expect(view.string == "line one\nline two\n")
}

@Test @MainActor func reloadingOverUnsavedTextCanBeUndoneBackToIt() async throws {
    let (document, source) = try await conflicted()
    defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

    document.reloadFromDisk()
    let view = shown(document)
    document.memory.undoManager.undo()
    #expect(view.string == "mine\n")
}

@Test func theRecordedChangeCoversOnlyWhatDiffers() {
    #expect(EditorMemory.change(from: "abcdef", to: "abXYef") == (NSRange(location: 2, length: 2), "XY"))
    #expect(EditorMemory.change(from: "abc", to: "abc") == (NSRange(location: 3, length: 0), ""))
    #expect(EditorMemory.change(from: "", to: "new") == (NSRange(location: 0, length: 0), "new"))
    #expect(EditorMemory.change(from: "aaa", to: "aa") == (NSRange(location: 2, length: 1), ""))
    #expect(EditorMemory.change(from: "olá 👋", to: "olá 👋!") == (NSRange(location: 6, length: 0), "!"))
}

@Test func aCursorFollowsItsTextWhenLinesChangeAboveIt() {
    let old = "a\nb\ncursor here\n"
    let position = CursorPosition.Position(line: 3, column: 4)
    #expect(EditorMemory.moved(position, from: old, to: "new\na\nb\ncursor here\n") == CursorPosition.Position(line: 4, column: 4))
    #expect(EditorMemory.moved(position, from: old, to: "b\ncursor here\n") == CursorPosition.Position(line: 2, column: 4))
    #expect(EditorMemory.moved(position, from: old, to: "a\nb\ncursor here\nmore below\n") == position)
    #expect(EditorMemory.moved(position, from: old, to: "a\nb\ncur") == CursorPosition.Position(line: 3, column: 4))
    #expect(EditorMemory.moved(CursorPosition.Position(line: 1, column: 2), from: "ab", to: "ab") == CursorPosition.Position(line: 1, column: 2))
    #expect(EditorMemory.moved(CursorPosition.Position(line: 1, column: 3), from: "ab", to: "abc") == CursorPosition.Position(line: 1, column: 3))
}

@MainActor
private func deletedWhileUnsaved() async throws -> (EditorDocument, URL) {
    let (document, source) = try await opened("a\n")
    document.text = "mine\n"
    try FileManager.default.removeItem(at: source)
    return (document, source)
}

@Test @MainActor func aDeletedFileWarnsAndSavingDoesNotBringItBack() async throws {
    let (document, source) = try await deletedWhileUnsaved()
    defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

    await document.readDisk()
    #expect(document.lostOnDisk == .deleted)
    #expect(document.text == "mine\n")
    document.save()
    #expect(!FileManager.default.fileExists(atPath: source.path))

    document.saveAnyway()
    #expect(document.lostOnDisk == nil)
    #expect(!document.isDirty)
    #expect(try String(contentsOf: source, encoding: .utf8) == "mine\n")
}

@Test @MainActor func savingAFileDeletedBeforeTheWatcherSawItWarnsFirst() async throws {
    let (document, source) = try await deletedWhileUnsaved()
    defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

    document.save()

    #expect(document.lostOnDisk == .deleted)
    #expect(document.isDirty)
    #expect(!FileManager.default.fileExists(atPath: source.path))
}

@Test @MainActor func aFileThatTurnsBinaryOrLeavesUTF8WarnsUntilItIsTextAgain() async throws {
    let (document, source) = try await opened("a\n")
    defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }

    try Data([0x41, 0x00, 0x42]).write(to: source)
    await document.readDisk()
    #expect(document.lostOnDisk == .unreadable("Arquivo binário."))
    #expect(document.text == "a\n")
    document.text = "mine\n"
    document.save()
    #expect(try Data(contentsOf: source) == Data([0x41, 0x00, 0x42]))

    try Data([0x63, 0xE3, 0x6F]).write(to: source)
    await document.readDisk()
    #expect(document.lostOnDisk == .unreadable("Este arquivo não está em UTF-8."))

    try Data("mine\n".utf8).write(to: source)
    await document.readDisk()
    #expect(document.lostOnDisk == nil)
    #expect(!document.isDirty)
}

@Test @MainActor func aDeletedFileReplacesTheWarningAboutAChangeOnDisk() async throws {
    let (document, source) = try await conflicted()
    defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
    document.compareWithDisk()

    try FileManager.default.removeItem(at: source)
    await document.readDisk()

    #expect(document.lostOnDisk == .deleted)
    #expect(document.changedOnDisk == nil)
    #expect(document.mode == .code)
}

@MainActor
func loaded(_ tabs: EditorTabs, _ names: [String], in row: SidebarRow, root: URL) async throws -> [EditorDocument] {
    for name in names { tabs.open(root.appending(path: name), in: row) }
    let documents = tabs.documents(in: row).filter { names.contains($0.name) }
    for _ in 0..<100 where documents.contains(where: { $0.kind == .loading }) {
        try await Task.sleep(for: .milliseconds(10))
    }
    return documents
}

@MainActor
private func twoTabs() async throws -> (EditorTabs, SidebarRow, [EditorDocument]) {
    let root = try makeTree([], files: ["a.ts", "b.ts"])
    let tabs = EditorTabs()
    let row = anyRow()
    return (tabs, row, try await loaded(tabs, ["a.ts", "b.ts"], in: row, root: root))
}

@Test @MainActor func leavingWithAnUnsavedTabCancelsDiscardsOrSavesIt() async throws {
    let (tabs, _, documents) = try await twoTabs()
    defer { try? FileManager.default.removeItem(at: documents[0].url.deletingLastPathComponent()) }
    let other = try await loaded(tabs, ["a.ts"], in: anyRow(), root: documents[0].url.deletingLastPathComponent())
    documents[0].text = "mine\n"

    #expect(other.first === documents[0])
    #expect(tabs.unsaved().map(ObjectIdentifier.init) == [ObjectIdentifier(documents[0])])
    #expect(!tabs.settle(.cancel))
    #expect(tabs.settle(.discard))
    #expect(try String(contentsOf: documents[0].url, encoding: .utf8).isEmpty)

    #expect(tabs.settle(.saveAll))
    #expect(try String(contentsOf: documents[0].url, encoding: .utf8) == "mine\n")
    #expect(tabs.unsaved().isEmpty)
}

@Test @MainActor func savingAllBeforeLeavingStopsAtAFileTheAgentDeleted() async throws {
    let (tabs, row, documents) = try await twoTabs()
    defer { try? FileManager.default.removeItem(at: documents[0].url.deletingLastPathComponent()) }
    documents.forEach { $0.text = "mine\n" }
    tabs.select(nil, in: row)
    try FileManager.default.removeItem(at: documents[1].url)

    #expect(!tabs.settle(.saveAll))

    #expect(try String(contentsOf: documents[0].url, encoding: .utf8) == "mine\n")
    #expect(!FileManager.default.fileExists(atPath: documents[1].url.path))
    #expect(documents[1].lostOnDisk == .deleted)
    #expect(tabs.selection(in: row) === documents[1])
}

@Test @MainActor func removingASessionClosesItsTabsAndLetsThemGo() async throws {
    let root = try makeTree([], files: ["a.ts", "b.ts"])
    defer { try? FileManager.default.removeItem(at: root) }
    let tabs = EditorTabs()
    let removed = anyRow()
    let kept = anyRow()
    var documents = try await loaded(tabs, ["a.ts", "b.ts"], in: removed, root: root)
    _ = try await loaded(tabs, ["b.ts"], in: kept, root: root)
    documents.forEach { $0.text = "mine\n" }
    weak let onlyThere = documents[0]

    #expect(tabs.unsaved(in: removed).map(\.name) == ["a.ts"])
    tabs.close(removed)
    documents = []

    #expect(tabs.documents(in: removed).isEmpty)
    #expect(tabs.selection(in: removed) == nil)
    #expect(tabs.documents(in: kept).map(\.name) == ["b.ts"])
    for _ in 0..<100 where onlyThere != nil {
        try await Task.sleep(for: .milliseconds(10))
    }
    #expect(onlyThere == nil)
}

@Test @MainActor func anOpenFileThatGrowsPastTheLimitStillSavesAndReloads() async throws {
    let (document, source) = try await opened("a\n")
    defer { try? FileManager.default.removeItem(at: source.deletingLastPathComponent()) }
    let large = String(repeating: "x", count: FileContents.sizeLimit + 1)

    document.text = large
    document.save()
    await document.readDisk()
    #expect(document.lostOnDisk == nil)
    #expect(!document.isDirty)

    try Data((large + "y").utf8).write(to: source)
    await document.readDisk()
    #expect(document.lostOnDisk == nil)
    #expect(document.text == large + "y")
}

@Test @MainActor func savingAllLeavesAFileWithAPendingChangeOnDiskForTheUserToSettle() async throws {
    let (tabs, row, documents) = try await twoTabs()
    defer { try? FileManager.default.removeItem(at: documents[0].url.deletingLastPathComponent()) }
    documents.forEach { $0.text = "mine\n" }
    try Data("agent\n".utf8).write(to: documents[0].url)
    await documents[0].readDisk()

    #expect(!tabs.settle(.saveAll, in: row))

    #expect(try String(contentsOf: documents[0].url, encoding: .utf8) == "agent\n")
    #expect(try String(contentsOf: documents[1].url, encoding: .utf8) == "mine\n")
    #expect(documents[0].changedOnDisk == "agent\n")
    #expect(tabs.selection(in: row) === documents[0])
    #expect(tabs.documents(in: row).count == 2)
}

@Test @MainActor func aTabOpenedOnAnUnreadableFileShowsTheTextOnceTheFileIsTextAgain() async throws {
    let root = try makeTree([])
    defer { try? FileManager.default.removeItem(at: root) }
    let source = root.appending(path: "Main.java")
    let document = EditorDocument(url: source)
    await document.load()
    #expect(document.kind == .unreadable("Este arquivo não existe mais."))

    try Data([0x41, 0x00, 0x42]).write(to: source)
    await document.readDisk()
    #expect(document.kind == .unreadable("Arquivo binário."))

    try Data("class Main {}\n".utf8).write(to: source)
    await document.readDisk()
    #expect(document.kind == .text)
    #expect(document.text == "class Main {}\n")
    #expect(!document.isDirty)
}
