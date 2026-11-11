import SwiftUI

struct RemoveBranchSheet: View {
    let removal: NsWorkspace.Removal
    let editors: EditorWindows
    let root: URL?
    var cancel: () -> Void
    var remove: (_ purge: Bool) -> Void

    @State private var purge = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DialogHeading(title: Text("Remover \(Text(removal.branch).font(Theme.font(.large, weight: .semibold, design: .monospaced)))?"),
                          subtitle: Text("Apaga as worktrees de todos os Repos. As Sessões desta branch ficam arquivadas."))
            VStack(alignment: .leading, spacing: Theme.space(.s12)) {
                content
            }
            .dialogBody()
            DialogFooter {
                Spacer(minLength: 0)
                DialogCancelButton(action: cancel)
                Button { remove(purge) } label: { Text("Remover branch").pillLabel() }
                    .buttonStyle(.thalamusDestructive)
                    .disabled(preview?.uncommitted.isEmpty != true || !unsaved.isEmpty)
            }
        }
        .frame(width: 500)
        .background(Theme.raised)
        .foregroundStyle(Theme.text)
    }

    private var unsaved: [EditorDocument] {
        editors.unsaved(in: .branch(removal.branch))
    }

    private func relative(_ url: URL) -> String {
        guard let root = root?.path, url.path.hasPrefix(root + "/") else { return url.path }
        return String(url.path.dropFirst(root.count + 1))
    }

    private var preview: NsClient.RemovalPreview? {
        if case .ready(let preview) = removal.state { preview } else { nil }
    }

    @ViewBuilder
    private var content: some View {
        switch removal.state {
        case .loading:
            HStack(spacing: Theme.space(.s8)) {
                ProgressView().controlSize(.small)
                Text("Procurando alterações não commitadas…")
                    .font(Theme.font(.smallPlus))
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(height: Theme.size(.s34))
        case .failed(let message):
            DialogWarning(title: "Não deu para verificar os Repos.", detail: message)
        case .ready(let preview):
            if !preview.uncommitted.isEmpty {
                DialogWarning(title: "Não dá para remover: há alterações não commitadas.",
                        detail: "Faça commit ou descarte e tente de novo.")
                VStack(spacing: 0) {
                    ForEach(Array(preview.uncommitted.enumerated()), id: \.element.repo) { index, repo in
                        UncommittedRow(repo: repo, isFirst: index == 0)
                    }
                }
                .dialogCard()
            }
            if !unsaved.isEmpty {
                DialogWarning(title: "Não dá para remover: há abas com alterações não salvas.",
                              detail: "Salve ou descarte e tente de novo.")
                VStack(alignment: .leading, spacing: Theme.space(.s4)) {
                    ForEach(unsaved, id: \.url) { document in
                        FileLine(path: relative(document.url))
                    }
                }
                .padding(Theme.space(.s10))
                .frame(maxWidth: .infinity, alignment: .leading)
                .dialogCard()
            }
            DialogCheckbox(title: "Apagar também o banco", isOn: $purge, note: "volume \(preview.volume)")
        }
    }
}

private struct UncommittedRow: View {
    let repo: NsClient.RemovalPreview.UncommittedRepo
    let isFirst: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space(.s6)) {
            HStack(spacing: Theme.space(.s10)) {
                Text(repo.repo)
                    .font(Theme.font(.smallPlus, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(repo.files.count == 1 ? "1 arquivo" : "\(repo.files.count) arquivos")
                    .font(Theme.font(.captionPlus, weight: .medium))
                    .foregroundStyle(Theme.alertText)
                    .padding(.horizontal, Theme.space(.s8))
                    .frame(height: Theme.size(.s22))
                    .background(Theme.alertFill, in: RoundedRectangle(cornerRadius: Theme.radius(.r7), style: .continuous))
            }
            VStack(alignment: .leading, spacing: Theme.space(.s4)) {
                ForEach(repo.files, id: \.self) { FileLine(path: $0) }
            }
        }
        .padding(Theme.space(.s10))
        .overlay(alignment: .top) {
            if !isFirst { Rectangle().fill(Theme.border).frame(height: Theme.line(.thin)) }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct FileLine: View {
    let path: String

    var body: some View {
        Text(path)
            .font(Theme.font(.captionPlus, design: .monospaced))
            .foregroundStyle(Theme.textSecondary)
            .lineLimit(1)
            .truncationMode(.head)
            .textSelection(.enabled)
            .help(path)
    }
}

private extension View {
    func dialogCard() -> some View {
        background(Theme.card, in: DialogBox.shape)
            .overlay(DialogBox.shape.strokeBorder(Theme.border))
    }
}
