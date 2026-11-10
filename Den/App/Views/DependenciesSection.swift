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
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 2)
        }
        if !rows.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    DependencyRow(row: row, isFirst: index == 0, isBusy: isBusy) {
                        Task { await dependencies.install(row.id, in: branch) }
                    }
                }
            }
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.borderCard, lineWidth: 1))
        }
    }
}

private struct DependencyRow: View {
    let row: BranchDependencies.Row
    let isFirst: Bool
    let isBusy: Bool
    var install: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                icon
                Text(row.id)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                action
            }
            .frame(minHeight: 26)
            if row.repo.state.needsInstall {
                VStack(alignment: .leading, spacing: 6) {
                    Text(note)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    if let failure = row.failure {
                        Text(failure)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Theme.removed)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                    CopyableCommand(command: row.repo.command)
                }
                .padding(.leading, 26)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            if !isFirst { Rectangle().fill(Theme.border).frame(height: 1) }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var action: some View {
        if row.isInstalling {
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text("Instalando…")
            }
            .font(.system(size: 11.5))
            .foregroundStyle(Theme.textMuted)
        } else if row.repo.state.needsInstall {
            let title = row.failure == nil ? "Instalar" : "Repetir"
            Button(action: install) { Text(title).pillLabel() }
                .buttonStyle(.thalamusSecondary)
                .disabled(isBusy)
                .help("\(title) as dependências do \(row.id)")
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
        return Image(systemName: symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 18, height: 18)
            .help(title)
            .accessibilityLabel(title)
    }

    static func style(of state: NsClient.RepoDependencies.State) -> (symbol: String, title: String, color: Color) {
        switch state {
        case .installed: ("checkmark", "Instaladas", Theme.added)
        case .reused: ("arrow.triangle.branch", "Da master", Theme.textTertiary)
        case .divergent: ("exclamationmark.triangle", "Da master, divergentes", Theme.alertText)
        case .missing: ("xmark", "Faltando", Theme.removed)
        }
    }
}

private struct CopyableCommand: View {
    let command: String

    @State private var copied = false

    var body: some View {
        HStack(spacing: 6) {
            Text(command)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button(copied ? "Copiado" : "Copiar", action: copy)
                .buttonStyle(.plain)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.textMuted)
                .help("Copiar o comando")
                .accessibilityLabel("Copiar \(command)")
        }
        .padding(.leading, 8)
        .padding(.trailing, 6)
        .padding(.vertical, 4)
        .background(Theme.canvas, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Theme.border))
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
