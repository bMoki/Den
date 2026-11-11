import SwiftUI

struct FilesPanel: View {
    let tree: FileTree
    let directory: URL
    let removedBranch: String?
    var open: (URL) -> Void
    var mention: ((_ path: String, _ isDirectory: Bool) -> Void)?

    @State private var naming: FileNameRequest?
    @State private var dropOnRoot = false
    @FocusState private var focused: Bool

    var body: some View {
        Group {
            if let removedBranch {
                gone(detail: "A branch \(removedBranch) foi removida.")
            } else if tree.isMissing, tree.root == directory.standardizedFileURL {
                gone(detail: nil)
            } else {
                VStack(alignment: .leading, spacing: Theme.space(.s2)) {
                    header
                    rows
                    footer
                }
                .padding(.horizontal, Theme.space(.s8))
                .padding(.bottom, Theme.space(.s8))
            }
        }
        .task(id: "\(directory.path)|\(removedBranch ?? "")") {
            if removedBranch == nil { await tree.watch(directory) }
        }
        .onChange(of: naming == nil) { if naming == nil { focused = true } }
        .sheet(item: $naming) { request in
            FileNameSheet(request: request, root: tree.root ?? directory, cancel: { naming = nil }, submit: { name in
                try perform(request, name: name)
                naming = nil
            })
        }
    }

    private var header: some View {
        HStack(spacing: Theme.space(.s2)) {
            Text(directory.lastPathComponent)
                .font(Theme.font(.small, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: Theme.space(.s4))
            headerButton(.newFile, title: "Novo arquivo") { ask(.newFile, at: tree.selectedNode) }
            headerButton(.newFolder, title: "Nova pasta") { ask(.newFolder, at: tree.selectedNode) }
            headerButton(.compact, title: "Recolher tudo", perform: tree.collapseAll)
        }
        .padding(.leading, Theme.space(.s6))
        .padding(.trailing, Theme.space(.s4))
        .frame(height: Theme.size(.s30))
        .background(dropOnRoot ? Theme.accentFill : .clear, in: RoundedRectangle(cornerRadius: Theme.radius(.r6), style: .continuous))
        .dropDestination(for: String.self) { paths, _ in
            drop(paths, into: tree.root ?? directory)
        } isTargeted: { dropOnRoot = $0 }
    }

    private var rows: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(tree.rows) { row in
                        FileTreeRow(row: row, isSelected: tree.selection == row.id) {
                            focused = true
                            tree.selection = row.id
                            if row.node.isDirectory { tree.toggle(row.node) } else { open(row.node.url) }
                        } drop: { paths in
                            drop(paths, into: row.node.url)
                        }
                        .id(row.id)
                        .thalamusContextMenu(menu(for: row.node))
                    }
                }
            }
            .onChange(of: tree.selection) {
                if let selection = tree.selection { proxy.scrollTo(selection) }
            }
        }
        .frame(maxHeight: .infinity)
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { press in
            guard let shortcut = FileTreeShortcut(key: press.key, characters: press.characters, modifiers: press.modifiers) else {
                return .ignored
            }
            run(shortcut)
            return .handled
        }
        .accessibilityIdentifier("file-tree")
    }

    @ViewBuilder
    private var footer: some View {
        if let problem = tree.problem {
            Text(problem)
                .font(Theme.font(.captionPlus))
                .foregroundStyle(Theme.alertText)
                .padding(.horizontal, Theme.space(.s6))
                .onTapGesture { tree.problem = nil }
        } else {
            Text(mention == nil ? "Clique com o botão direito num arquivo para criar, renomear, mover ou excluir."
                : "Clique com o botão direito num arquivo para criar, renomear, mover, excluir ou mencioná-lo na Sessão.")
                .font(Theme.font(.captionPlus))
                .foregroundStyle(Theme.textFaint)
                .padding(.horizontal, Theme.space(.s6))
        }
    }

    private func gone(detail: String?) -> some View {
        VStack(spacing: Theme.space(.s8)) {
            Theme.image(.folder)
                .font(Theme.font(.title))
                .foregroundStyle(Theme.textFaint)
            Text("A pasta desta Sessão não existe mais")
                .font(Theme.font(.body, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            if let detail {
                Text(detail)
                    .font(Theme.font(.small))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .multilineTextAlignment(.center)
        .padding(Theme.space(.s30))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func headerButton(_ symbol: Icon, title: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Theme.image(symbol)
                .font(Theme.font(.small, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
                .iconLabel(size: .s26)
        }
        .buttonStyle(.thalamusGhost)
        .help(title)
        .accessibilityLabel(title)
    }

    private func menu(for node: FileNode) -> [ThalamusMenuSection] {
        let mentioning = mention.map { mention in
            ThalamusMenuSection(id: "mention", items: [
                ThalamusMenuItem(id: "mention", title: "Mencionar na Sessão", icon: icon(.mention)) {
                    mention(tree.relativePath(of: node), node.isDirectory)
                },
            ])
        }
        return [mentioning].compactMap { $0 } + [
            ThalamusMenuSection(id: "edit", items: [
                ThalamusMenuItem(id: "new-file", title: "Novo arquivo", icon: icon(.newFile)) { ask(.newFile, at: node) },
                ThalamusMenuItem(id: "new-folder", title: "Nova pasta", icon: icon(.newFolder)) { ask(.newFolder, at: node) },
                ThalamusMenuItem(id: "rename", title: "Renomear", icon: icon(.edit), shortcut: FileTreeShortcut.rename.hint) {
                    rename(node)
                },
                ThalamusMenuItem(id: "move", title: "Mover para…", icon: icon(.move)) { move(node) },
            ]),
            ThalamusMenuSection(id: "place", items: [
                ThalamusMenuItem(id: "reveal", title: "Revelar no Finder", icon: icon(.search)) { tree.revealInFinder(node) },
                ThalamusMenuItem(id: "copy-path", title: "Copiar caminho", icon: icon(.copy),
                            shortcut: FileTreeShortcut.copyPath.hint) { tree.copyPath(node) },
            ]),
            ThalamusMenuSection(id: "trash", items: [
                ThalamusMenuItem(id: "trash", title: "Mover para a lixeira", icon: .symbol(.trash, Theme.removed),
                            isDestructive: true, shortcut: FileTreeShortcut.trash.hint) { attempt { try tree.trash(node) } },
            ]),
        ]
    }

    private func icon(_ symbol: Icon) -> ThalamusMenuIcon {
        .symbol(symbol, Theme.textTertiary)
    }

    private func run(_ shortcut: FileTreeShortcut) {
        switch shortcut {
        case .next: tree.selectNext()
        case .previous: tree.selectPrevious()
        case .open: tree.openSelection()
        case .close: tree.closeSelection()
        case .rename: if let node = tree.selectedNode { rename(node) }
        case .copyPath: if let node = tree.selectedNode { tree.copyPath(node) }
        case .trash: if let node = tree.selectedNode { attempt { try tree.trash(node) } }
        }
    }

    private func rename(_ node: FileNode) {
        naming = FileNameRequest(kind: .rename(node), folder: node.url.deletingLastPathComponent())
    }

    private func drop(_ paths: [String], into folder: URL) -> Bool {
        guard let path = paths.first else { return false }
        return attempt { try tree.drop(path, into: folder) }
    }

    private func ask(_ kind: FileNameRequest.Kind, at node: FileNode?) {
        guard let folder = tree.targetFolder(for: node) else { return }
        naming = FileNameRequest(kind: kind, folder: folder)
    }

    private func perform(_ request: FileNameRequest, name: String) throws {
        switch request.kind {
        case .newFile: try tree.create(named: name, in: request.folder, isDirectory: false)
        case .newFolder: try tree.create(named: name, in: request.folder, isDirectory: true)
        case .rename(let node): try tree.rename(node, to: name)
        }
    }

    private func move(_ node: FileNode) {
        guard let folder = FolderPicker.choose(prompt: "Mover para cá", from: node.url.deletingLastPathComponent()) else { return }
        attempt { try tree.move(node, into: folder) }
    }

    @discardableResult
    private func attempt(_ action: () throws -> Void) -> Bool {
        do {
            try action()
            tree.problem = nil
            return true
        } catch {
            tree.problem = error.localizedDescription
            return false
        }
    }
}

private struct FileTreeRow: View {
    let row: FileTree.Row
    let isSelected: Bool
    var select: () -> Void
    var drop: ([String]) -> Bool

    @State private var hovering = false
    @State private var targeted = false

    var body: some View {
        Button(action: select) {
            HStack(spacing: Theme.space(.s6)) {
                Theme.image(.next)
                    .font(Theme.font(.mini, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .rotationEffect(.degrees(row.isExpanded ? 90 : 0))
                    .frame(width: Theme.size(.s12))
                    .opacity(row.node.isDirectory ? 1 : 0)
                Theme.image(symbol)
                    .font(Theme.font(.small))
                    .foregroundStyle(row.isIgnored ? Theme.textFaint : row.node.isDirectory ? Theme.accent : Theme.textTertiary)
                    .frame(width: Theme.size(.s14))
                Text(row.node.name)
                    .font(Theme.font(.smallPlus))
                    .foregroundStyle(nameColor)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: Theme.space(.s4))
                if let state = row.state {
                    Text(row.node.isDirectory ? "●" : FileTreeMark.letter(state))
                        .font(Theme.font(.labelPlus, weight: .semibold, design: .monospaced))
                        .foregroundStyle(state.color)
                }
            }
            .padding(.leading, CGFloat(row.depth) * 14 + 4)
            .padding(.trailing, Theme.space(.s8))
            .frame(height: Theme.size(.s26))
            .background(isSelected || targeted ? Theme.accentFill : hovering ? Theme.hover : .clear,
                        in: RoundedRectangle(cornerRadius: Theme.radius(.r6), style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .draggable(row.node.id)
        .dropDestination(for: String.self) { paths, _ in
            row.node.isDirectory && drop(paths)
        } isTargeted: { targeted = row.node.isDirectory && $0 }
        .accessibilityLabel(row.node.name)
        .accessibilityValue(accessibilitySummary)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var symbol: Icon {
        if row.node.isDirectory { return .folder }
        return FileTreeMark.isImage(row.node.name) ? .image : .file
    }

    private var nameColor: Color {
        if row.isIgnored { return Theme.textFaint }
        guard let state = row.state, !row.node.isDirectory else { return Theme.textSecondary }
        return state.color
    }

    private var accessibilitySummary: String {
        var parts: [String] = []
        if row.node.isDirectory { parts.append(row.isExpanded ? "pasta aberta" : "pasta fechada") }
        if let state = row.state { parts.append(state.accessibilityName) }
        if row.isIgnored { parts.append("ignorado pelo git") }
        return parts.joined(separator: ", ")
    }
}
