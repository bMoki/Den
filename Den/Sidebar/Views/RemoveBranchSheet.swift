import SwiftUI

struct RemoveBranchSheet: View {
    let removal: NsWorkspace.Removal
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
                Button(action: cancel) { Text("Cancelar").pillLabel() }
                    .buttonStyle(.denSecondary)
                    .keyboardShortcut(.cancelAction)
                Button { remove(purge) } label: { Text("Remover branch").pillLabel() }
                    .buttonStyle(.denDestructive)
                    .disabled(preview?.uncommitted.isEmpty != true)
            }
        }
        .frame(width: 500)
        .background(Theme.raised)
        .foregroundStyle(Theme.text)
        .preferredColorScheme(.dark)
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
            Warning(title: "Não deu para verificar os Repos.", detail: message)
        case .ready(let preview):
            if !preview.uncommitted.isEmpty {
                Warning(title: "Não dá para remover: há alterações não commitadas.",
                        detail: "Faça commit ou descarte e tente de novo.")
                VStack(spacing: 0) {
                    ForEach(Array(preview.uncommitted.enumerated()), id: \.element.repo) { index, repo in
                        UncommittedRow(repo: repo, isFirst: index == 0)
                    }
                }
                .background(Theme.card, in: DialogBox.shape)
                .overlay(DialogBox.shape.strokeBorder(Theme.border))
            }
            DialogCheckbox(title: "Apagar também o banco", isOn: $purge, note: "volume \(preview.volume)")
        }
    }
}

private struct Warning: View {
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 9) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 12))
            Text("\(title) \(Text(detail).foregroundStyle(Theme.alertText.opacity(0.8)))")
                .font(.system(size: 12.5))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .foregroundStyle(Theme.alertText)
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.alertFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.alertBorder))
        .accessibilityElement(children: .combine)
    }
}

private struct UncommittedRow: View {
    let repo: NsClient.RemovalPreview.UncommittedRepo
    let isFirst: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(repo.repo)
                .font(.system(size: 12.5, design: .monospaced))
            Text(files)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(repo.files.joined(separator: "\n"))
            Text(repo.files.count == 1 ? "1 arquivo" : "\(repo.files.count) arquivos")
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Theme.alertText)
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(Theme.alertFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .padding(.horizontal, 10)
        .frame(height: 36)
        .overlay(alignment: .top) {
            if !isFirst { Rectangle().fill(Theme.border).frame(height: 1) }
        }
        .accessibilityElement(children: .combine)
    }

    private var files: String {
        let names = repo.files.prefix(2).map { URL(fileURLWithPath: $0).lastPathComponent }
        let rest = repo.files.count - names.count
        return names.joined(separator: ", ") + (rest > 0 ? " +\(rest)" : "")
    }
}
