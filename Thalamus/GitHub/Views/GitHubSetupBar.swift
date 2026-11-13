import SwiftUI
import AppKit

struct GitHubSetupBar: View {
    let state: GitHubCLIState
    var choose: () -> Void
    var retry: () -> Void
    var dismiss: () -> Void

    var body: some View {
        HStack(spacing: Theme.space(.s10)) {
            Theme.image(.terminal, size: .small, weight: .semibold)
                .foregroundStyle(Theme.textTertiary)
            Text(message)
                .font(Theme.font(.smallPlus))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
            } label: {
                HStack(spacing: Theme.space(.s6)) {
                    Theme.image(.copy, size: .label)
                    Text("Copiar")
                    Text(command)
                        .font(Theme.font(.captionPlus, design: .monospaced))
                        .foregroundStyle(Theme.accentSoft)
                }
                .barButtonLabel()
            }
            .buttonStyle(ThalamusButtonStyle(kind: .secondary, radius: .r7))
            .fixedSize()
            if case .missing = state {
                Button(action: choose) {
                    Text("Já tenho, escolher…")
                        .barButtonLabel()
                }
                .buttonStyle(ThalamusButtonStyle(kind: .secondary, radius: .r7))
                .fixedSize()
            }
            Button(action: retry) {
                Text("Tentar de novo")
                    .font(Theme.font(.small, weight: .medium))
                    .foregroundStyle(Theme.accentSoft)
                    .padding(.horizontal, Theme.space(.s8))
                    .frame(height: Theme.size(.s26))
            }
            .buttonStyle(.thalamusGhost(radius: .r7))
            .fixedSize()
            BarDismissButton(action: dismiss)
        }
        .barSurface(fill: Theme.card, stroke: Theme.borderCard)
    }

    private var message: String {
        if case .notLoggedIn(let host) = state { return "O gh precisa de login em \(host)" }
        return "Instale o GitHub CLI para o Thalamus acompanhar seus PRs"
    }

    private var command: String {
        if case .notLoggedIn = state { return "gh auth login" }
        return "brew install gh"
    }
}
