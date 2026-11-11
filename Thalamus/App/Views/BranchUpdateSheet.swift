import SwiftUI

struct BranchUpdateSheet: View {
    let report: NsWorkspace.UpdateReport
    var close: () -> Void

    private var branch: Text {
        Text(report.branch).font(Theme.font(.smallPlus, design: .monospaced))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DialogHeading(title: Text(BranchActionTitle.update),
                          subtitle: Text("Trouxe a branch principal de cada Repo para \(branch)."))
            VStack(alignment: .leading, spacing: Theme.space(.s14)) {
                VStack(spacing: 0) {
                    ForEach(Array(report.repos.enumerated()), id: \.element.repo) { index, repo in
                        RepoUpdateRow(repo: repo, isFirst: index == 0)
                    }
                }
                if let conflictNote {
                    Text(conflictNote)
                        .font(Theme.font(.smallPlus))
                        .foregroundStyle(Theme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .dialogBody()
            DialogFooter {
                Spacer(minLength: 0)
                Button(action: close) { Text("Fechar").pillLabel() }
                    .buttonStyle(.thalamusPrimary)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .frame(width: 560)
        .background(Theme.raised)
        .foregroundStyle(Theme.text)
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
        HStack(spacing: Theme.space(.s10)) {
            Text(repo.repo)
                .font(Theme.font(.smallPlus, design: .monospaced))
                .frame(width: 110, alignment: .leading)
            Text(detail)
                .font(Theme.font(.small))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(repo.message ?? "")
                .textSelection(.enabled)
            pill
        }
        .padding(.horizontal, Theme.space(.s2))
        .padding(.vertical, Theme.space(.s9))
        .overlay(alignment: .top) {
            if !isFirst { Rectangle().fill(Theme.border).frame(height: Theme.line(.thin)) }
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
        var symbol: Icon?
        let color: Color
        let fill: Color
    }

    private var style: PillStyle {
        switch repo.status {
        case .updated: PillStyle(title: "Atualizado", symbol: .done, color: Theme.added, fill: Theme.addedFill)
        case .conflict:
            PillStyle(title: "Conflito", symbol: .warning, color: Theme.removed, fill: Theme.removedFill)
        case .failed: PillStyle(title: "Falhou", symbol: .close, color: Theme.removed, fill: Theme.removedFill)
        case .skipped: PillStyle(title: "Ignorado", color: Theme.alertText, fill: Theme.alertFill)
        case .upToDate: PillStyle(title: "Já em dia", color: Theme.textSecondary, fill: Theme.field)
        }
    }

    private var pill: some View {
        let style = style
        return HStack(spacing: Theme.space(.s5)) {
            if let symbol = style.symbol {
                Theme.image(symbol).font(Theme.font(.mini, weight: .bold))
            }
            Text(style.title).font(Theme.font(.captionPlus, weight: .medium))
        }
        .foregroundStyle(style.color)
        .padding(.horizontal, Theme.space(.s8))
        .frame(height: Theme.size(.s24))
        .background(style.fill, in: RoundedRectangle(cornerRadius: Theme.radius(.r7), style: .continuous))
    }
}
