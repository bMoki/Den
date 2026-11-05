import SwiftUI

struct BranchUpdateSheet: View {
    let report: NsWorkspace.UpdateReport
    var close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DialogHeading(title: Text(BranchActionTitle.update),
                          subtitle: Text("Trouxe a branch principal de cada Repo para \(Text(report.branch).font(.system(size: 12.5, design: .monospaced)))."))
            VStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 0) {
                    ForEach(Array(report.repos.enumerated()), id: \.element.repo) { index, repo in
                        RepoUpdateRow(repo: repo, isFirst: index == 0)
                    }
                }
                if let conflictNote {
                    Text(conflictNote)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(EdgeInsets(top: 14, leading: 20, bottom: 4, trailing: 20))
            DialogFooter {
                Spacer(minLength: 0)
                Button(action: close) { Text("Fechar").pillLabel() }
                    .buttonStyle(.denPrimary)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(width: 560)
        .background(Theme.raised)
        .foregroundStyle(Theme.text)
        .preferredColorScheme(.dark)
    }

    private var conflictNote: String? {
        let repos = report.repos.filter { $0.status == .conflict }.map(\.repo)
        guard let last = repos.last else { return nil }
        let names = repos.dropLast().joined(separator: ", ") + " e " + last
        let subject = repos.count == 1 ? "O conflito em \(last) ficou" : "Os conflitos em \(names) ficaram"
        return "\(subject) em aberto. Peça a resolução na Sessão em que você está."
    }
}

private struct RepoUpdateRow: View {
    let repo: RepoUpdate
    let isFirst: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(repo.repo)
                .font(.system(size: 12.5, design: .monospaced))
                .frame(width: 110, alignment: .leading)
            Text(detail)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(repo.message ?? "")
                .textSelection(.enabled)
            pill
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 9)
        .overlay(alignment: .top) {
            if !isFirst { Rectangle().fill(Theme.border).frame(height: 1) }
        }
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        switch repo.status {
        case .updated:
            let source = repo.branch.map { "de \($0)" } ?? ""
            guard let commits = repo.commits else { return source }
            return "\(commits) \(commits == 1 ? "commit" : "commits") \(source)"
        case .conflict:
            let files = repo.conflicts ?? []
            guard let first = files.first else { return "conflito" }
            return "conflito em \(first)" + (files.count > 1 ? " +\(files.count - 1)" : "")
        case .upToDate:
            return ""
        case .skipped, .failed:
            return repo.message?.split(separator: "\n").first.map(String.init) ?? ""
        }
    }

    private struct PillStyle {
        let title: String
        var symbol: String?
        let color: Color
        let fill: Color
    }

    private var style: PillStyle {
        switch repo.status {
        case .updated: PillStyle(title: "Atualizado", symbol: "checkmark", color: Theme.added, fill: Theme.addedFill)
        case .conflict:
            PillStyle(title: "Conflito", symbol: "exclamationmark.triangle", color: Theme.removed, fill: Theme.removedFill)
        case .failed: PillStyle(title: "Falhou", symbol: "xmark", color: Theme.removed, fill: Theme.removedFill)
        case .skipped: PillStyle(title: "Ignorado", color: Theme.alertText, fill: Theme.alertFill)
        case .upToDate: PillStyle(title: "Já em dia", color: Theme.textSecondary, fill: Theme.field)
        }
    }

    private var pill: some View {
        let style = style
        return HStack(spacing: 5) {
            if let symbol = style.symbol {
                Image(systemName: symbol).font(.system(size: 9, weight: .bold))
            }
            Text(style.title).font(.system(size: 11.5, weight: .medium))
        }
        .foregroundStyle(style.color)
        .padding(.horizontal, 8)
        .frame(height: 24)
        .background(style.fill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}
