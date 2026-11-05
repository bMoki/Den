import CodeEditSourceEditor
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
    #expect(FileContents.read(root.appending(path: "missing.txt")) == .unreadable("Não consegui abrir este arquivo."))
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
    let session = UUID()
    let other = UUID()

    tabs.open(root.appending(path: "a.ts"), in: session)
    tabs.open(root.appending(path: "b.yaml"), in: session)
    tabs.open(root.appending(path: "a.ts"), in: session)

    #expect(tabs.documents(in: session).map(\.name) == ["a.ts", "b.yaml"])
    #expect(tabs.selection(in: session)?.name == "a.ts")
    #expect(tabs.documents(in: other).isEmpty)
    #expect(tabs.selection(in: other) == nil)

    tabs.select(nil, in: session)
    #expect(tabs.selection(in: session) == nil)
}

@Test @MainActor func closingTheShownTabShowsTheNextOneOrTheSession() throws {
    let root = try makeTree([], files: ["a.ts", "b.ts", "c.ts"])
    defer { try? FileManager.default.removeItem(at: root) }
    let tabs = EditorTabs()
    let session = UUID()
    for name in ["a.ts", "b.ts", "c.ts"] { tabs.open(root.appending(path: name), in: session) }
    let documents = tabs.documents(in: session)

    tabs.select(documents[1], in: session)
    tabs.close(documents[1], in: session)
    #expect(tabs.selection(in: session)?.name == "c.ts")

    tabs.close(documents[2], in: session)
    #expect(tabs.selection(in: session)?.name == "a.ts")

    tabs.close(documents[0], in: session)
    #expect(tabs.selection(in: session) == nil)
    #expect(tabs.documents(in: session).isEmpty)
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
    let first = UUID()
    let second = UUID()

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

    #expect(document.problem == "A pasta deste arquivo não existe mais.")
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
