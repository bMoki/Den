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
            DialogHeading(title: Text("Remover \(Text(removal.branch).font(.system(size: 14, weight: .semibold, design: .monospaced)))?"),
                          subtitle: Text("Apaga as worktrees de todos os Repos. As Sessões desta branch ficam arquivadas."))
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(EdgeInsets(top: 14, leading: 20, bottom: 4, trailing: 20))
            DialogFooter {
                Spacer(minLength: 0)
                DialogCancelButton(action: cancel)
                Button { remove(purge) } label: { Text("Remover branch").pillLabel() }
                    .buttonStyle(.denDestructive)
                    .disabled(preview?.uncommitted.isEmpty != true || !unsaved.isEmpty)
            }
        }
        .frame(width: 500)
        .background(Theme.raised)
        .foregroundStyle(Theme.text)
        .preferredColorScheme(.dark)
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
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Procurando alterações não commitadas…")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(height: 34)
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
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(unsaved, id: \.url) { document in
                        FileLine(path: relative(document.url))
                    }
                }
                .padding(10)
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text(repo.repo)
                    .font(.system(size: 12.5, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(repo.files.count == 1 ? "1 arquivo" : "\(repo.files.count) arquivos")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.alertText)
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(Theme.alertFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 4) {
                ForEach(repo.files, id: \.self) { FileLine(path: $0) }
            }
        }
        .padding(10)
        .overlay(alignment: .top) {
            if !isFirst { Rectangle().fill(Theme.border).frame(height: 1) }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct FileLine: View {
    let path: String

    var body: some View {
        Text(path)
            .font(.system(size: 11.5, design: .monospaced))
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
