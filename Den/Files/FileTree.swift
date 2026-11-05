import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class FileTree {
    struct Row: Identifiable {
        let node: FileNode
        let depth: Int
        let isExpanded: Bool
        let state: GitFileState?
        let isIgnored: Bool

        var id: String { node.id }
    }

    nonisolated enum Problem: LocalizedError, Equatable {
        case emptyName
        case slashInName
        case exists(String)
        case insideItself
        case outsideFolder(String)
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .emptyName: "Escolha um nome."
            case .slashInName: "O nome não pode ter '/'."
            case .exists(let name): "Já existe \(name) aqui."
            case .insideItself: "Uma pasta não pode ir para dentro dela mesma."
            case .outsideFolder(let folder): "Escolha uma pasta dentro de \(folder)."
            case .failed(let reason): reason
            }
        }
    }

    private(set) var root: URL?
    private(set) var listings: [String: [FileNode]] = [:]
    private(set) var expanded: Set<String> = []
    private(set) var marks = GitMarks()
    private(set) var isMissing = false
    var selection: String?
    var problem: String?

    @ObservationIgnored private var expandedByRoot: [String: Set<String>] = [:]
    @ObservationIgnored private var marksTask: Task<Void, Never>?
    @ObservationIgnored private var marksPending = false

    var rows: [Row] {
        guard let root else { return [] }
        var rows: [Row] = []
        func add(_ folder: String, depth: Int, ignored: Bool) {
            for node in listings[folder] ?? [] {
                let isExpanded = node.isDirectory && expanded.contains(node.id)
                let isIgnored = ignored || marks.isIgnoredItself(node.id)
                rows.append(Row(node: node, depth: depth, isExpanded: isExpanded,
                                state: marks.state(of: node), isIgnored: isIgnored))
                if isExpanded { add(node.id, depth: depth + 1, ignored: isIgnored) }
            }
        }
        add(root.path, depth: 0, ignored: marks.isIgnored(root.path))
        return rows
    }

    func watch(_ folder: URL) async {
        let folder = folder.standardizedFileURL
        open(folder)
        let gitDirectories = await Task.detached(priority: .utility) {
            GitRepository.repoRoots(under: folder).map(GitRepository.gitDirectory(of:))
                .filter { !$0.path.hasPrefix(folder.path + "/") }
        }.value
        guard root == folder, !Task.isCancelled else { return }
        let changes = FolderWatcher.changes(in: folder, alsoWatching: gitDirectories)
        await reload([folder.path] + expanded.sorted())
        refreshMarks()
        for await paths in changes {
            guard root == folder else { return }
            await apply(paths)
        }
    }

    func toggle(_ node: FileNode) {
        guard node.isDirectory else { return }
        if expanded.remove(node.id) == nil {
            expanded.insert(node.id)
            let opened = [node.id] + expanded.filter { $0.hasPrefix(node.id + "/") }.sorted()
            Task { await reload(opened) }
        }
    }

    func collapseAll() {
        expanded = []
    }

    func relativePath(of node: FileNode) -> String {
        guard let root, node.id.hasPrefix(root.path + "/") else { return node.name }
        return String(node.id.dropFirst(root.path.count + 1))
    }

    func targetFolder(for node: FileNode?) -> URL? {
        guard let node else { return root }
        return node.isDirectory ? node.url : node.url.deletingLastPathComponent()
    }

    nonisolated static func nameProblem(_ name: String, in folder: URL, except current: URL? = nil) -> Problem? {
        let name = name.trimmingCharacters(in: .whitespaces)
        if name.isEmpty || name == "." || name == ".." { return .emptyName }
        if name.contains("/") { return .slashInName }
        let target = folder.appending(path: name)
        let isCurrent = target.path.lowercased() == current?.path.lowercased()
        if !isCurrent, FileManager.default.fileExists(atPath: target.path) { return .exists(name) }
        return nil
    }

    func create(named name: String, in folder: URL, isDirectory: Bool) throws {
        if let problem = Self.nameProblem(name, in: folder) { throw problem }
        let target = folder.appending(path: name.trimmingCharacters(in: .whitespaces))
        if isDirectory {
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        } else if !FileManager.default.createFile(atPath: target.path, contents: Data()) {
            throw Problem.failed("Não consegui criar \(target.lastPathComponent).")
        }
        reveal(target)
    }

    func rename(_ node: FileNode, to name: String) throws {
        let folder = node.url.deletingLastPathComponent()
        if let problem = Self.nameProblem(name, in: folder, except: node.url) { throw problem }
        try relocate(node, to: folder.appending(path: name.trimmingCharacters(in: .whitespaces)))
    }

    func move(_ node: FileNode, into folder: URL) throws {
        let folder = folder.standardizedFileURL
        if let root, folder.path != root.path, !folder.path.hasPrefix(root.path + "/") {
            throw Problem.outsideFolder(root.lastPathComponent)
        }
        if folder.path == node.id || folder.path.hasPrefix(node.id + "/") { throw Problem.insideItself }
        if folder.path == node.url.deletingLastPathComponent().path { return }
        if let problem = Self.nameProblem(node.name, in: folder) { throw problem }
        try relocate(node, to: folder.appending(path: node.name))
    }

    func trash(_ node: FileNode) throws {
        try FileManager.default.trashItem(at: node.url, resultingItemURL: nil)
        forget(node.id)
        Task { await reload([node.url.deletingLastPathComponent().path]) }
    }

    func revealInFinder(_ node: FileNode) {
        NSWorkspace.shared.activateFileViewerSelecting([node.url])
    }

    func copyPath(_ node: FileNode) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(node.id, forType: .string)
    }

    private func relocate(_ node: FileNode, to target: URL) throws {
        try FileManager.default.moveItem(at: node.url, to: target)
        let moved = expanded.filter { $0 == node.id || $0.hasPrefix(node.id + "/") }
        forget(node.id)
        let reopened = moved.map { target.path + String($0.dropFirst(node.id.count)) }
        expanded.formUnion(reopened)
        reveal(target)
        Task { await reload([node.url.deletingLastPathComponent().path] + reopened.sorted()) }
    }

    private func reveal(_ target: URL) {
        var folder = target.deletingLastPathComponent()
        var opened: [String] = []
        while let root, folder.path.hasPrefix(root.path + "/") {
            opened.append(folder.path)
            folder = folder.deletingLastPathComponent()
        }
        expanded.formUnion(opened)
        selection = target.path
        Task { await reload([root?.path].compactMap { $0 } + opened.reversed()) }
    }

    private func forget(_ path: String) {
        expanded = expanded.filter { $0 != path && !$0.hasPrefix(path + "/") }
        listings = listings.filter { $0.key != path && !$0.key.hasPrefix(path + "/") }
        if let selection, selection == path || selection.hasPrefix(path + "/") { self.selection = nil }
    }

    private func open(_ folder: URL) {
        guard root != folder else { return }
        if let root { expandedByRoot[root.path] = expanded }
        marksTask?.cancel()
        marksTask = nil
        marksPending = false
        root = folder
        listings = [:]
        expanded = expandedByRoot[folder.path] ?? []
        marks = GitMarks()
        isMissing = false
        selection = nil
        problem = nil
    }

    private func apply(_ paths: [String]) async {
        guard let root else { return }
        let folders = Set(listings.keys).union([root.path]).filter { folder in
            paths.contains { $0 == folder || folder.hasPrefix($0 + "/") }
        }
        await reload(folders.sorted())
        if paths.contains(where: { !marks.isIgnored($0) || Self.isGitMetadata($0) }) { refreshMarks() }
    }

    private static func isGitMetadata(_ path: String) -> Bool {
        path.hasSuffix("/.git") || path.contains("/.git/")
    }

    private func reload(_ folders: [String]) async {
        guard let root else { return }
        let loaded = await Task.detached(priority: .userInitiated) {
            folders.map { ($0, FileNode.children(of: URL(fileURLWithPath: $0))) }
        }.value
        guard self.root == root else { return }
        for (folder, nodes) in loaded {
            if folder == root.path { isMissing = nodes == nil }
            if let nodes {
                if listings[folder] != nodes { listings[folder] = nodes }
            } else {
                forget(folder)
            }
        }
    }

    private func refreshMarks() {
        guard let root else { return }
        guard marksTask == nil else {
            marksPending = true
            return
        }
        marksTask = Task {
            repeat {
                marksPending = false
                let read = await Task.detached(priority: .utility) { await GitMarks.read(under: root) }.value
                guard !Task.isCancelled, self.root == root else { return }
                if marks != read { marks = read }
            } while marksPending
            marksTask = nil
        }
    }
}
