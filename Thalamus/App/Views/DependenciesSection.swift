import AppKit
import SwiftUI

struct DependenciesSection: View {
    let branch: String
    let isBusy: Bool

    @Environment(NsWorkspace.self) private var ns

    var body: some View {
        let dependencies = ns.dependencies
        let rows = dependencies.rows(of: branch)
        if let problem = dependencies.problems[branch] {
            Text(problem)
                .font(Theme.font(.captionPlus))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.space(.s2))
        }
        if !rows.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    DependencyRow(row: row, isFirst: index == 0, isBusy: isBusy) {
                        Task { await dependencies.install(row.id, in: branch) }
                    }
                }
            }
            .card()
        }
    }
}

private struct DependencyRow: View {
    let row: BranchDependencies.Row
    let isFirst: Bool
    let isBusy: Bool
    var install: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space(.s8)) {
            HStack(spacing: Theme.space(.s8)) {
                icon
                Text(row.id)
                    .font(Theme.font(.small, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: Theme.space(.s4))
                action
            }
            .frame(minHeight: Theme.size(.s26))
            if row.repo.state.needsInstall {
                VStack(alignment: .leading, spacing: Theme.space(.s6)) {
                    Text(note)
                        .font(Theme.font(.captionPlus))
                        .foregroundStyle(Theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    if let failure = row.failure {
                        Text(failure)
                            .font(Theme.font(.caption, design: .monospaced))
                            .foregroundStyle(Theme.removed)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    CopyableCommand(command: row.repo.command)
                }
                .padding(.leading, Theme.space(.s26))
            }
        }
        .padding(.leading, Theme.space(.s10))
        .padding(.trailing, Theme.space(.s8))
        .padding(.vertical, Theme.space(.s8))
        .overlay(alignment: .top) {
            if !isFirst { Rectangle().fill(Theme.border).frame(height: Theme.line(.thin)) }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var action: some View {
        if row.isInstalling {
            HStack(spacing: Theme.space(.s6)) {
                ProgressView().controlSize(.mini)
                Text("Instalando…")
            }
            .font(Theme.font(.captionPlus))
            .foregroundStyle(Theme.textMuted)
        } else if row.repo.state.needsInstall {
            let title = row.failure == nil ? "Instalar" : "Repetir"
            Button(action: install) { Text(title).pillLabel() }
                .buttonStyle(.thalamusSecondary)
                .disabled(isBusy)
                .tip("\(title) as dependências do \(row.id)")
                .accessibilityLabel("\(title) as dependências do \(row.id)")
        }
    }

    private var note: String {
        switch row.repo.state {
        case .divergent: "Vieram da master e diferem do que a branch declara. Os Serviços sobem, mas podem não funcionar."
        case .missing: "Sem dependências instaladas: a instalação foi recusada ou falhou."
        case .installed, .reused: ""
        }
    }

    private var icon: some View {
        let (symbol, title, color) = Self.style(of: row.repo.state)
        return Theme.image(symbol, size: .caption, weight: .semibold)
            .foregroundStyle(color)
            .frame(width: Theme.size(.s18), height: Theme.size(.s18))
            .tip(title)
            .accessibilityLabel(title)
    }

    static func style(of state: NsClient.RepoDependencies.State) -> (symbol: Icon, title: String, color: Color) {
        switch state {
        case .installed: (.done, "Instaladas", Theme.added)
        case .reused: (.branch, "Da master", Theme.textTertiary)
        case .divergent: (.warning, "Da master, divergentes", Theme.alertText)
        case .missing: (.close, "Faltando", Theme.removed)
        }
    }
}

private struct CopyableCommand: View {
    let command: String

    @State private var copied = false

    var body: some View {
        HStack(spacing: Theme.space(.s6)) {
            Text(command)
                .font(Theme.font(.caption, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(copied ? "Copiado" : "Copiar", action: copy)
                .buttonStyle(.plain)
                .font(Theme.font(.labelPlus))
                .foregroundStyle(Theme.textMuted)
                .tip("Copiar o comando")
                .accessibilityLabel("Copiar \(command)")
        }
        .padding(.leading, Theme.space(.s8))
        .padding(.trailing, Theme.space(.s6))
        .padding(.vertical, Theme.space(.s4))
        .background(Theme.canvas, in: RoundedRectangle(cornerRadius: Theme.radius(.r6), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius(.r6), style: .continuous).strokeBorder(Theme.border))
    }

    private func copy() {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(command, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}
