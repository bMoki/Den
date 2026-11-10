import Testing
import Foundation
@testable import Thalamus

private func write(_ text: String, to path: String, in directory: URL) throws {
    let file = directory.appending(path: path)
    try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try text.write(to: file, atomically: true, encoding: .utf8)
}

@MainActor
private func watching(_ folder: URL, _ body: (FileTree) async throws -> Void) async throws {
    let tree = FileTree()
    let watch = Task { await tree.watch(folder) }
    defer { watch.cancel() }
    #expect(await eventually { !tree.rows.isEmpty || tree.isMissing })
    try await body(tree)
}

@MainActor
private func names(_ tree: FileTree) -> [String] {
    tree.rows.map { String(repeating: "  ", count: $0.depth) + $0.node.name }
}

@MainActor
private func row(_ name: String, in tree: FileTree) -> FileTree.Row? {
    tree.rows.first { $0.node.name == name }
}

@Test func childrenListFoldersFirstAndHideTheGitFolder() throws {
    let root = try makeTree([".git", "src", "Assets"], files: ["b.txt", "A.txt", ".DS_Store", ".env"])
    defer { try? FileManager.default.removeItem(at: root) }

    let names = try #require(FileNode.children(of: root)).map(\.name)
    #expect(names == ["Assets", "src", ".env", "A.txt", "b.txt"])
}

@Test func childrenOfAMissingFolderAreNil() {
    #expect(FileNode.children(of: URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)")) == nil)
}

@Test @MainActor func theTreeShowsTheFolderAndOpensSubfoldersOnDemand() async throws {
    let root = try makeTree(["src/deep"], files: ["src/main.swift", "README.md"])
    defer { try? FileManager.default.removeItem(at: root) }

    try await watching(root) { tree in
        #expect(names(tree) == ["src", "README.md"])
        tree.toggle(try #require(row("src", in: tree)).node)
        #expect(await eventually { names(tree) == ["src", "  deep", "  main.swift", "README.md"] })
        tree.toggle(try #require(row("src", in: tree)).node)
        #expect(names(tree) == ["src", "README.md"])
    }
}

@Test @MainActor func switchingFoldersSwitchesTheTreeAndKeepsWhatWasOpen() async throws {
    let first = try makeTree(["one"], files: ["one/inside.txt"])
    let second = try makeTree([], files: ["two.txt"])
    defer {
        try? FileManager.default.removeItem(at: first)
        try? FileManager.default.removeItem(at: second)
    }
    let tree = FileTree()

    var watch = Task { await tree.watch(first) }
    #expect(await eventually { names(tree) == ["one"] })
    tree.toggle(try #require(row("one", in: tree)).node)
    #expect(await eventually { names(tree) == ["one", "  inside.txt"] })
    watch.cancel()

    watch = Task { await tree.watch(second) }
    #expect(await eventually { names(tree) == ["two.txt"] })
    watch.cancel()

    watch = Task { await tree.watch(first) }
    #expect(await eventually { names(tree) == ["one", "  inside.txt"] })
    watch.cancel()
}

@Test @MainActor func aMissingFolderIsReported() async {
    let tree = FileTree()
    let watch = Task { await tree.watch(URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)")) }
    defer { watch.cancel() }
    #expect(await eventually { tree.isMissing })
}

@Test @MainActor func filesShowTheirGitStateAndIgnoredOnesAreFlagged() async throws {
    let root = try makeTree([])
    defer { try? FileManager.default.removeItem(at: root) }
    let repo = root.appending(path: "backend")
    try FileManager.default.createDirectory(at: repo, withIntermediateDirectories: true)
    try await git(["init", "-q", "-b", "main"], in: repo)
    try write("node_modules/\n*.log\n", to: ".gitignore", in: repo)
    try write("one\n", to: "src/Kept.swift", in: repo)
    try write("one\n", to: "src/Changed.swift", in: repo)
    try await git(["add", "."], in: repo)
    try await git(["commit", "-q", "-m", "initial"], in: repo)
    try write("two\n", to: "src/Changed.swift", in: repo)
    try write("new\n", to: "src/New.swift", in: repo)
    try write("{}", to: "node_modules/pkg/index.js", in: repo)
    try write("noise", to: "debug.log", in: repo)

    try await watching(root) { tree in
        tree.toggle(try #require(row("backend", in: tree)).node)
        #expect(await eventually { row("src", in: tree) != nil })
        tree.toggle(try #require(row("src", in: tree)).node)
        #expect(await eventually { row("New.swift", in: tree)?.state == .untracked })

        #expect(row("Changed.swift", in: tree)?.state == .modified)
        #expect(row("Kept.swift", in: tree)?.state == nil)
        #expect(row("src", in: tree)?.state == .modified)
        #expect(row("backend", in: tree)?.state == .modified)
        #expect(row("node_modules", in: tree)?.isIgnored == true)
        #expect(row("debug.log", in: tree)?.isIgnored == true)
        #expect(row("src", in: tree)?.isIgnored == false)

        tree.toggle(try #require(row("node_modules", in: tree)).node)
        #expect(await eventually { row("pkg", in: tree)?.isIgnored == true })
    }
}

@Test func aFolderWithOnlyNewFilesIsMarkedNew() {
    let root = URL(fileURLWithPath: "/work")
    let marks = GitMarks(root: root, repos: [
        GitMarks.Repo(root: root, entries: [GitStatusEntry(path: "fresh/a.txt", state: .untracked)], ignored: []),
    ])
    #expect(marks.state(of: FileNode(url: root.appending(path: "fresh"), isDirectory: true)) == .untracked)
    #expect(marks.state(of: FileNode(url: root.appending(path: "fresh/a.txt"), isDirectory: false)) == .untracked)
}

@Test @MainActor func creatingRenamingMovingAndTrashingChangeTheDisk() async throws {
    let root = try makeTree(["docs"], files: ["notes.txt"])
    defer { try? FileManager.default.removeItem(at: root) }
    let manager = FileManager.default

    try await watching(root) { tree in
        try tree.create(named: "draft.md", in: root.appending(path: "docs"), isDirectory: false)
        #expect(manager.fileExists(atPath: root.appending(path: "docs/draft.md").path))
        #expect(await eventually { names(tree) == ["docs", "  draft.md", "notes.txt"] })
        #expect(tree.selection == root.appending(path: "docs/draft.md").path)

        try tree.create(named: "archive", in: root, isDirectory: true)
        #expect(root.appending(path: "archive").isExistingDirectory)

        try tree.rename(try #require(row("notes.txt", in: tree)).node, to: "todo.txt")
        #expect(manager.fileExists(atPath: root.appending(path: "todo.txt").path))
        #expect(!manager.fileExists(atPath: root.appending(path: "notes.txt").path))

        #expect(await eventually { row("todo.txt", in: tree) != nil })
        try tree.move(try #require(row("todo.txt", in: tree)).node, into: root.appending(path: "archive"))
        #expect(manager.fileExists(atPath: root.appending(path: "archive/todo.txt").path))
        #expect(await eventually { names(tree) == ["archive", "  todo.txt", "docs", "  draft.md"] })

        try tree.trash(try #require(row("draft.md", in: tree)).node)
        #expect(!manager.fileExists(atPath: root.appending(path: "docs/draft.md").path))
        #expect(await eventually { names(tree) == ["archive", "  todo.txt", "docs"] })
    }
}

@Test @MainActor func renamingAnOpenFolderKeepsItOpen() async throws {
    let root = try makeTree(["old"], files: ["old/a.txt"])
    defer { try? FileManager.default.removeItem(at: root) }

    try await watching(root) { tree in
        tree.toggle(try #require(row("old", in: tree)).node)
        #expect(await eventually { names(tree) == ["old", "  a.txt"] })
        try tree.rename(try #require(row("old", in: tree)).node, to: "new")
        #expect(await eventually { names(tree) == ["new", "  a.txt"] })
    }
}

@Test @MainActor func operationsRefuseBadNamesAndMoves() async throws {
    let root = try makeTree(["box/inner"], files: ["taken.txt"])
    defer { try? FileManager.default.removeItem(at: root) }

    #expect(FileTree.nameProblem("  ", in: root) == .emptyName)
    #expect(FileTree.nameProblem("a/b", in: root) == .slashInName)
    #expect(FileTree.nameProblem("taken.txt", in: root) == .exists("taken.txt"))
    #expect(FileTree.nameProblem("taken.txt", in: root, except: root.appending(path: "taken.txt")) == nil)

    try await watching(root) { tree in
        let box = try #require(row("box", in: tree)).node
        #expect(throws: FileTree.Problem.insideItself) { try tree.move(box, into: root.appending(path: "box/inner")) }
        #expect(throws: FileTree.Problem.exists("taken.txt")) {
            try tree.create(named: "taken.txt", in: root, isDirectory: false)
        }
    }
}

@Test @MainActor func changesMadeOutsideTheAppShowUpOnTheirOwn() async throws {
    let root = try makeTree(["src"], files: ["src/a.txt"])
    defer { try? FileManager.default.removeItem(at: root) }

    try await watching(root) { tree in
        tree.toggle(try #require(row("src", in: tree)).node)
        #expect(await eventually { names(tree) == ["src", "  a.txt"] })

        try write("x", to: "src/b.txt", in: root)
        try FileManager.default.removeItem(at: root.appending(path: "src/a.txt"))
        #expect(await eventually { names(tree) == ["src", "  b.txt"] })

        try write("y", to: "top.txt", in: root)
        #expect(await eventually { names(tree) == ["src", "  b.txt", "top.txt"] })
    }
}

@Test @MainActor func theRelativePathIsWhatTheSessionMentions() async throws {
    let root = try makeTree(["src"], files: ["src/main.swift"])
    defer { try? FileManager.default.removeItem(at: root) }

    try await watching(root) { tree in
        let src = try #require(row("src", in: tree)).node
        #expect(tree.relativePath(of: src) == "src")
        tree.toggle(src)
        #expect(await eventually { row("main.swift", in: tree) != nil })
        #expect(tree.relativePath(of: try #require(row("main.swift", in: tree)).node) == "src/main.swift")
    }
}

@Test @MainActor func mentioningAFileAppendsItToTheComposer() {
    let chat = inertChat()
    let mentions = MentionController()

    mentions.mention("src/main.swift", isDirectory: false, in: chat)
    #expect(chat.prompt == "@src/main.swift ")

    chat.prompt = "olhe"
    mentions.mention("src", isDirectory: true, in: chat)
    #expect(chat.prompt == "olhe @src/ ")
}

@Test func watcherPathsAreShownUnderTheFolderAsOpened() {
    #expect(FolderWatcher.path("/private/tmp/x/src/", real: "/private/tmp/x", shown: "/tmp/x") == "/tmp/x/src")
    #expect(FolderWatcher.path("/private/tmp/x", real: "/private/tmp/x", shown: "/tmp/x") == "/tmp/x")
    #expect(FolderWatcher.path("/elsewhere/y", real: "/private/tmp/x", shown: "/tmp/x") == "/elsewhere/y")
}

@Test @MainActor func movingOutOfTheSessionFolderIsRefused() async throws {
    let root = try makeTree([], files: ["a.txt"])
    let elsewhere = try makeTree([])
    defer {
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.removeItem(at: elsewhere)
    }

    try await watching(root) { tree in
        let file = try #require(row("a.txt", in: tree)).node
        #expect(throws: FileTree.Problem.outsideFolder(root.lastPathComponent)) { try tree.move(file, into: elsewhere) }
        #expect(FileManager.default.fileExists(atPath: file.id))
    }
}

@Test func renamingOnlyTheLetterCaseIsAllowed() throws {
    let root = try makeTree([], files: ["readme.md"])
    defer { try? FileManager.default.removeItem(at: root) }
    #expect(FileTree.nameProblem("README.md", in: root, except: root.appending(path: "readme.md")) == nil)
}

@Test @MainActor func aFolderThatComesBackIsShownAgain() async throws {
    let root = try makeTree([], files: ["a.txt"])
    defer { try? FileManager.default.removeItem(at: root) }

    try await watching(root) { tree in
        try FileManager.default.removeItem(at: root)
        #expect(await eventually { tree.isMissing })
        try write("x", to: "b.txt", in: root)
        #expect(await eventually { !tree.isMissing && names(tree) == ["b.txt"] })
    }
}

@Test @MainActor func stagingInAWorktreeUpdatesTheMarks() async throws {
    let base = try makeTree([])
    defer { try? FileManager.default.removeItem(at: base) }
    let main = base.appending(path: "main")
    let worktree = base.appending(path: "feature")
    try FileManager.default.createDirectory(at: main, withIntermediateDirectories: true)
    try await git(["init", "-q", "-b", "main"], in: main)
    try write("one\n", to: "kept.txt", in: main)
    try await git(["add", "."], in: main)
    try await git(["commit", "-q", "-m", "initial"], in: main)
    try await git(["worktree", "add", "-q", "-b", "feature", worktree.path], in: main)
    try write("new\n", to: "fresh.txt", in: worktree)

    try await watching(worktree) { tree in
        #expect(await eventually { row("fresh.txt", in: tree)?.state == .untracked })
        try await git(["add", "fresh.txt"], in: worktree)
        #expect(await eventually { row("fresh.txt", in: tree)?.state == .added })
    }
}

@Test @MainActor func arrowsWalkTheRowsAndOpenAndCloseFolders() async throws {
    let root = try makeTree(["src/deep"], files: ["src/main.swift", "README.md"])
    defer { try? FileManager.default.removeItem(at: root) }

    try await watching(root) { tree in
        let path = { (name: String) in root.appending(path: name).path }
        tree.selectNext()
        #expect(tree.selection == path("src"))
        tree.openSelection()
        #expect(await eventually { names(tree) == ["src", "  deep", "  main.swift", "README.md"] })
        tree.openSelection()
        #expect(tree.selection == path("src/deep"))
        tree.selectNext()
        tree.selectNext()
        #expect(tree.selection == path("README.md"))
        tree.selectNext()
        #expect(tree.selection == path("README.md"))
        tree.selectPrevious()
        #expect(tree.selection == path("src/main.swift"))
        tree.openSelection()
        #expect(tree.selection == path("src/main.swift"))
        tree.closeSelection()
        #expect(tree.selection == path("src"))
        tree.closeSelection()
        #expect(names(tree) == ["src", "README.md"])
        tree.selectPrevious()
        #expect(tree.selection == path("src"))
    }
}

@Test @MainActor func droppingAnItemOnAFolderMovesIt() async throws {
    let root = try makeTree(["archive", "box/inner"], files: ["notes.txt"])
    defer { try? FileManager.default.removeItem(at: root) }
    let manager = FileManager.default

    try await watching(root) { tree in
        try tree.drop(root.appending(path: "notes.txt").path, into: root.appending(path: "archive"))
        #expect(manager.fileExists(atPath: root.appending(path: "archive/notes.txt").path))
        #expect(await eventually { names(tree) == ["archive", "  notes.txt", "box"] })

        try tree.drop(root.appending(path: "archive/notes.txt").path, into: root)
        #expect(manager.fileExists(atPath: root.appending(path: "notes.txt").path))

        try tree.drop(root.appending(path: "box").path, into: root.appending(path: "archive"))
        #expect(root.appending(path: "archive/box/inner").isExistingDirectory)
    }
}

@Test @MainActor func droppingWhereTheMoveIsNotAllowedChangesNothing() async throws {
    let root = try makeTree(["box/inner"], files: ["a.txt"])
    let elsewhere = try makeTree([], files: ["outside.txt"])
    defer {
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.removeItem(at: elsewhere)
    }
    let manager = FileManager.default

    try await watching(root) { tree in
        let folder = root.lastPathComponent
        #expect(throws: FileTree.Problem.insideItself) {
            try tree.drop(root.appending(path: "box").path, into: root.appending(path: "box/inner"))
        }
        #expect(throws: FileTree.Problem.outsideFolder(folder)) { try tree.drop(root.appending(path: "a.txt").path, into: elsewhere) }
        #expect(throws: FileTree.Problem.fromOutside(folder)) {
            try tree.drop(elsewhere.appending(path: "outside.txt").path, into: root.appending(path: "box"))
        }
        #expect(throws: FileTree.Problem.insideItself) { try tree.drop(root.path, into: root.appending(path: "box")) }
        try tree.drop(root.appending(path: "box").path, into: root.appending(path: "box"))
        try tree.drop("some selected text", into: root.appending(path: "box"))
        try tree.drop(root.appending(path: "missing.txt").path, into: root.appending(path: "box"))
        #expect(manager.fileExists(atPath: root.appending(path: "a.txt").path))
        #expect(manager.fileExists(atPath: elsewhere.appending(path: "outside.txt").path))
        #expect(root.appending(path: "box/inner").isExistingDirectory)
    }
}

@Test @MainActor func trashingTheSelectedItemSelectsTheNextOne() async throws {
    let root = try makeTree(["box"], files: ["box/inside.txt", "a.txt", "b.txt"])
    defer { try? FileManager.default.removeItem(at: root) }

    try await watching(root) { tree in
        tree.toggle(try #require(row("box", in: tree)).node)
        #expect(await eventually { names(tree) == ["box", "  inside.txt", "a.txt", "b.txt"] })
        tree.selection = root.appending(path: "box").path
        try tree.trash(try #require(tree.selectedNode))
        #expect(tree.selection == root.appending(path: "a.txt").path)
        tree.selection = root.appending(path: "b.txt").path
        try tree.trash(try #require(tree.selectedNode))
        #expect(tree.selection == root.appending(path: "a.txt").path)
    }
}
