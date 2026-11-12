import SwiftUI
import UniformTypeIdentifiers

enum FileTypeIcon {
    private static var cache: [String: NSImage] = [:]

    private static let overrides: [String: String] = [
        "ts": "com.microsoft.typescript",
    ]

    private static let icons: [String: Icon] = [
        "java": .javaFile,
        "js": .javaScriptFile, "mjs": .javaScriptFile, "cjs": .javaScriptFile,
        "jsx": .reactFile, "tsx": .reactFile,
        "swift": .swiftFile,
        "ts": .typeScriptFile,
    ]

    static func image(for name: String) -> NSImage {
        let ext = (name as NSString).pathExtension.lowercased()
        let key = Theme.style.id + "." + ext
        if let cached = cache[key] { return cached }

        if let icon = icons[ext], let custom = Theme.nsImage(icon) {
            cache[key] = custom
            return custom
        }
        let type: UTType? = overrides[ext].flatMap { UTType($0) }
            ?? UTType(filenameExtension: ext)
            ?? UTType(filenameExtension: ext, conformingTo: .sourceCode)
        let image = NSWorkspace.shared.icon(for: type ?? .plainText)
        cache[key] = image
        return image
    }
}

struct GitChangesPanel: View {
    let model: GitChangesModel
    let directory: URL

    @State private var selection: String?
    @State private var openFolders: Set<String> = []
    @State private var collapsedRepos: Set<String> = []

    private static var listRowHeight: CGFloat { Theme.size(.s30) }
    private static let maxListHeight: CGFloat = 260

    var body: some View {
        VStack(spacing: 0) {
            summary
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var summary: some View {
        let totals = model.repos.flatMap(\.files).reduce(into: (added: 0, removed: 0)) {
            let counts = Self.counts(of: $1)
            $0.added += counts.added
            $0.removed += counts.removed
        }
        return HStack(spacing: Theme.space(.s8)) {
            if model.changeCount > 0 {
                Text(model.changeCount == 1 ? "1 arquivo" : "\(model.changeCount) arquivos")
                    .foregroundStyle(Theme.textSecondary)
                Text("+\(totals.added)")
                    .font(Theme.font(.small, design: .monospaced))
                    .foregroundStyle(Theme.added)
                Text("−\(totals.removed)")
                    .font(Theme.font(.small, design: .monospaced))
                    .foregroundStyle(Theme.removed)
                if model.reviewedCount > 0 {
                    Text("· \(model.reviewedCount)/\(model.changeCount) revisados")
                        .foregroundStyle(model.reviewedCount == model.changeCount
                                         ? Theme.added : Theme.textTertiary)
                        .tip("Arquivos revisados")
                }
            } else {
                Text("Alterações do Git")
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer(minLength: Theme.space(.s4))
            if model.isLoading, model.loadedOnce {
                ProgressView().controlSize(.mini)
            }
            Button {
                Task { await model.load(directory: directory, force: true) }
            } label: {
                Theme.image(.restart)
                    .font(Theme.font(.small, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .iconLabel(size: .s26)
            }
            .buttonStyle(.thalamusGhost(radius: .r7))
            .disabled(model.isLoading)
            .tip("Atualizar alterações")
            .accessibilityLabel("Atualizar alterações")
        }
        .font(Theme.font(.body))
        .padding(.leading, Theme.space(.s16))
        .padding(.trailing, Theme.space(.s10))
        .frame(height: Theme.size(.s44))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: Theme.line(.thin)) }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if !model.loadedOnce {
            placeholder { ProgressView().controlSize(.small) }
        } else if !model.hasRepo {
            placeholder {
                Theme.image(.notARepository)
                    .font(Theme.font(.largeTitle))
                    .foregroundStyle(Theme.textFaint)
                Text("Sem repositório Git nesta pasta")
                    .font(Theme.font(.body))
                    .foregroundStyle(Theme.textTertiary)
            }
        } else if model.changeCount == 0 {
            placeholder {
                Theme.image(.clean)
                    .font(Theme.font(.largeTitle))
                    .foregroundStyle(Theme.added)
                Text("Sem alterações")
                    .font(Theme.font(.body, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                if let branch = model.repos.first?.branch {
                    Text("Tudo limpo em \(branch)")
                        .font(Theme.font(.small, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        } else {
            let selected = selectedFile
            fileList
            if let selected {
                fileHeader(selected.file, in: selected.repo)
                diff(selected.file)
            } else {
                Spacer()
            }
        }
    }

    private func placeholder(@ViewBuilder body: () -> some View) -> some View {
        VStack(spacing: Theme.space(.s8)) { body() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func key(_ file: GitChangesModel.FileChange, in repo: GitChangesModel.Repo) -> String {
        repo.id + "/" + file.path
    }

    private var selectedFile: (file: GitChangesModel.FileChange, repo: GitChangesModel.Repo)? {
        let all = model.repos.flatMap { repo in repo.files.map { (file: $0, repo: repo) } }
        if let selection, let match = all.first(where: { key($0.file, in: $0.repo) == selection }) {
            return match
        }
        return all.first { !model.isReviewed($0.file, in: $0.repo) } ?? all.first
    }

    private var visibleRowCount: Int {
        model.repos.reduce(0) { total, repo in
            var rows = model.repos.count > 1 ? 1 : 0
            if !collapsedRepos.contains(repo.id) {
                for item in repo.items {
                    switch item {
                    case .single: rows += 1
                    case .group(let dir, let files):
                        rows += 1
                        if openFolders.contains(repo.id + "/" + dir) { rows += files.count }
                    }
                }
                if repo.truncatedFiles { rows += 1 }
            }
            return total + rows
        }
    }

    private var fileList: some View {
        let height = min(CGFloat(visibleRowCount) * (Self.listRowHeight + Theme.line(.thin)) + Theme.space(.s12),
                         Self.maxListHeight)
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.space(.s1)) {
                ForEach(model.repos) { repo in
                    if model.repos.count > 1 {
                        repoHeader(repo)
                    }
                    if !collapsedRepos.contains(repo.id) {
                        ForEach(repo.items) { item in
                            switch item {
                            case .single(let file):
                                fileRow(file, in: repo)
                            case .group(let dir, let files):
                                groupRow(dir: dir, files: files, in: repo)
                                if openFolders.contains(repo.id + "/" + dir) {
                                    ForEach(files) { file in
                                        fileRow(file, in: repo, within: dir)
                                            .padding(.leading, Theme.space(.s18))
                                    }
                                }
                            }
                        }
                        if repo.truncatedFiles {
                            Text("Mostrando só os primeiros arquivos")
                                .font(Theme.font(.captionPlus))
                                .foregroundStyle(Theme.textTertiary)
                                .padding(.horizontal, Theme.space(.s10))
                                .frame(height: Self.listRowHeight)
                        }
                    }
                }
            }
            .padding(Theme.space(.s6))
        }
        .scrollIndicators(.automatic)
        .frame(height: height)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: Theme.line(.thin)) }
    }

    private func repoHeader(_ repo: GitChangesModel.Repo) -> some View {
        let isCollapsed = collapsedRepos.contains(repo.id)
        return Button {
            withAnimation(.easeOut(duration: 0.15)) {
                if isCollapsed {
                    collapsedRepos.remove(repo.id)
                } else {
                    collapsedRepos.insert(repo.id)
                }
            }
        } label: {
            HStack(spacing: Theme.space(.s7)) {
                Theme.image(.next)
                    .font(Theme.font(.mini, weight: .bold))
                    .foregroundStyle(Theme.textTertiary)
                    .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                Theme.image(.branch)
                    .font(Theme.font(.caption, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text(repo.name)
                    .font(Theme.font(.smallPlus, weight: .semibold))
                if let branch = repo.branch {
                    Text(branch)
                        .font(Theme.font(.captionPlus, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer(minLength: 0)
                Text("\(repo.files.count)")
                    .font(Theme.font(.caption))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, Theme.space(.s8))
            .frame(height: Self.listRowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.thalamusGhost(radius: .r7))
        .tip(repo.root.path)
        .accessibilityLabel(isCollapsed ? "Expandir \(repo.name)" : "Recolher \(repo.name)")
    }

    private func fileRow(_ file: GitChangesModel.FileChange, in repo: GitChangesModel.Repo,
                         within dir: String? = nil) -> some View {
        let rowKey = key(file, in: repo)
        let isSelected = selectedFile.map { key($0.file, in: $0.repo) } == rowKey
        let done = model.isReviewed(file, in: repo)
        let counts = Self.counts(of: file)
        let display = dir.map { String(file.path.dropFirst($0.count)) }
            ?? sessionRelativePath(of: file.path, in: repo)
        return HStack(spacing: Theme.space(.s8)) {
            Button {
                selection = rowKey
            } label: {
                HStack(spacing: Theme.space(.s9)) {
                    badge(for: file.state)
                    pathText(display: display)
                        .opacity(done ? 0.5 : 1)
                        .lineLimit(1)
                        .truncationMode(.head)
                    Spacer(minLength: Theme.space(.s4))
                    if counts.added > 0 {
                        Text("+\(counts.added)")
                            .foregroundStyle(Theme.added)
                    }
                    if counts.removed > 0 {
                        Text("−\(counts.removed)")
                            .foregroundStyle(Theme.removed)
                    }
                }
                .modifier(ListRowLabel(height: Self.listRowHeight))
            }
            .buttonStyle(.plain)
            .tip(file.path)

            reviewButton(done: done) {
                model.setReviewed(!done, for: file, in: repo)
            }
            .padding(.trailing, Theme.space(.s4))
        }
        .hoverFill(selected: isSelected, radius: .r7)
    }

    private func groupRow(dir: String, files: [GitChangesModel.FileChange],
                          in repo: GitChangesModel.Repo) -> some View {
        let folderKey = repo.id + "/" + dir
        let isOpen = openFolders.contains(folderKey)
        let reviewed = files.count { model.isReviewed($0, in: repo) }
        let allDone = reviewed == files.count && !files.isEmpty
        let displayDir = dir.hasSuffix("/") ? String(dir.dropLast()) : dir
        return HStack(spacing: Theme.space(.s8)) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    if isOpen { openFolders.remove(folderKey) } else { openFolders.insert(folderKey) }
                }
            } label: {
                HStack(spacing: Theme.space(.s9)) {
                    badge(for: .untracked)
                    Theme.image(.next)
                        .font(Theme.font(.tiny, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                    Theme.image(isOpen ? .folderWithSessions : .folder)
                        .font(Theme.font(.caption))
                        .foregroundStyle(allDone ? Theme.textTertiary : Theme.accent)
                    pathText(display: sessionRelativePath(of: displayDir, in: repo) + "/")
                        .opacity(allDone ? 0.5 : 1)
                        .lineLimit(1)
                        .truncationMode(.head)
                    Spacer(minLength: Theme.space(.s4))
                    Text(reviewed > 0 ? "\(reviewed)/\(files.count)" : "\(files.count)")
                        .foregroundStyle(allDone ? Theme.added : Theme.textTertiary)
                }
                .modifier(ListRowLabel(height: Self.listRowHeight))
            }
            .buttonStyle(.plain)
            .tip(dir)

            reviewButton(done: allDone) {
                withAnimation(.easeOut(duration: 0.15)) {
                    for file in files { model.setReviewed(!allDone, for: file, in: repo) }
                }
            }
            .padding(.trailing, Theme.space(.s4))
        }
    }

    private func reviewButton(done: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Theme.image(done ? .taskDone : .radioOff)
                .font(Theme.font(.body))
                .foregroundStyle(done ? Theme.added : Theme.textFaint)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: Theme.size(.s22), height: Theme.size(.s22))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tip(done ? "Desmarcar como revisado" : "Marcar como revisado")
        .accessibilityLabel(done ? "Revisado" : "Não revisado")
    }

    private func fileHeader(_ file: GitChangesModel.FileChange,
                            in repo: GitChangesModel.Repo) -> some View {
        let done = model.isReviewed(file, in: repo)
        return HStack(spacing: Theme.space(.s8)) {
            Image(nsImage: FileTypeIcon.image(for: file.name))
                .resizable()
                .scaledToFit()
                .frame(width: Theme.size(.s18), height: Theme.size(.s18))
            Text(sessionRelativePath(of: file.path, in: repo))
                .font(Theme.font(.smallPlus, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.head)
                .tip(file.path)
            Spacer(minLength: Theme.space(.s6))
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    model.setReviewed(!done, for: file, in: repo)
                }
            } label: {
                HStack(spacing: Theme.space(.s5)) {
                    Theme.image(done ? .taskDone : .clean)
                    Text(done ? "Revisado" : "Marcar revisado")
                }
                .font(Theme.font(.small, weight: .medium))
                .foregroundStyle(done ? Theme.added : Theme.textSecondary)
                .padding(.horizontal, Theme.space(.s10))
                .frame(height: Theme.size(.s26))
            }
            .buttonStyle(ThalamusButtonStyle(kind: .secondary, radius: .r7))
        }
        .padding(.leading, Theme.space(.s14))
        .padding(.trailing, Theme.space(.s10))
        .frame(height: Theme.size(.s42))
        .background(Theme.raised)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: Theme.line(.thin)) }
    }

    private func diff(_ file: GitChangesModel.FileChange) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if file.lines.isEmpty {
                    Text(file.state == .deleted ? "Arquivo apagado" : "Sem diff para mostrar")
                        .font(Theme.font(.small))
                        .foregroundStyle(Theme.textTertiary)
                        .padding(Theme.space(.s14))
                }
                ForEach(file.lines) { line in
                    GitDiffRow(line: line)
                }
                if file.truncated {
                    Text("Diff longo — mostrando o início")
                        .font(Theme.font(.captionPlus))
                        .italic()
                        .foregroundStyle(Theme.textTertiary)
                        .padding(.horizontal, Theme.space(.s14))
                        .padding(.vertical, Theme.space(.s8))
                }
            }
            .padding(.vertical, Theme.space(.s4))
            .textSelection(.enabled)
        }
        .id(file.path)
        .frame(maxHeight: .infinity)
    }

    static func counts(of file: GitChangesModel.FileChange) -> (added: Int, removed: Int) {
        file.lines.reduce(into: (added: 0, removed: 0)) { totals, line in
            switch line.kind {
            case .added: totals.added += 1
            case .removed: totals.removed += 1
            case .hunk, .context: break
            }
        }
    }

    private func sessionRelativePath(of path: String,
                                     in repo: GitChangesModel.Repo) -> String {
        let full = repo.root.appending(path: path).standardizedFileURL.path
        let base = directory.standardizedFileURL.path
        let fullParts = full.split(separator: "/").map(String.init)
        let baseParts = base.split(separator: "/").map(String.init)
        var shared = 0
        while shared < min(fullParts.count, baseParts.count),
              fullParts[shared] == baseParts[shared] {
            shared += 1
        }
        let ups = Array(repeating: "..", count: baseParts.count - shared)
        return (ups + fullParts[shared...]).joined(separator: "/")
    }

    private func pathText(display relative: String) -> Text {
        let trimmed = relative.hasSuffix("/") ? String(relative.dropLast()) : relative
        let folder = (trimmed as NSString).deletingLastPathComponent
        let name = (trimmed as NSString).lastPathComponent + (relative.hasSuffix("/") ? "/" : "")
        let nameText = Text(name).foregroundStyle(Theme.text)
        guard !folder.isEmpty else { return nameText }
        let folderText = Text(folder + "/").foregroundStyle(Theme.textTertiary)
        return Text("\(folderText)\(nameText)")
    }

    private func badge(for state: GitFileState) -> some View {
        Text(state.badge)
            .font(Theme.font(.caption, weight: .semibold, design: .monospaced))
            .foregroundStyle(state.color)
            .frame(width: Theme.size(.s14))
            .accessibilityLabel(state.accessibilityName)
    }

}

private struct ListRowLabel: ViewModifier {
    let height: CGFloat

    func body(content: Content) -> some View {
        content
            .font(Theme.font(.captionPlus, design: .monospaced))
            .padding(.leading, Theme.space(.s8))
            .frame(height: height)
            .contentShape(Rectangle())
    }
}
