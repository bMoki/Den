import SwiftUI

struct SessionWelcome: View {
    let chat: ChatModel

    var body: some View {
        VStack(spacing: Theme.space(.s18)) {
            HarnessBadge(harness: chat.harness, size: .s40)
            VStack(spacing: Theme.space(.s5)) {
                Text("\(chat.harnessName) em \(chat.workingDirectory.lastPathComponent)")
                    .font(Theme.font(.title3, weight: .semibold))
                Text("Descreva o que quer mudar. O agente lê, edita e executa no projeto.")
                    .font(Theme.font(.body))
                    .foregroundStyle(Theme.textTertiary)
                    .multilineTextAlignment(.center)
            }
            HStack(spacing: Theme.space(.s8)) {
                hint(Text("@").font(Theme.font(.small, weight: .semibold, design: .monospaced)),
                     "cita arquivos")
                hint(Text("/").font(Theme.font(.small, weight: .semibold, design: .monospaced)),
                     "abre comandos")
                hint(Theme.image(.attach).font(Theme.font(.caption, weight: .medium)),
                     "anexa imagens e PDFs")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.space(.s120))
    }

    private func hint(_ glyph: some View, _ text: String) -> some View {
        HStack(spacing: Theme.space(.s6)) {
            glyph
                .foregroundStyle(Theme.accent)
            Text(text)
                .font(Theme.font(.small))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.horizontal, Theme.space(.s10))
        .frame(height: Theme.size(.s28))
        .background(Theme.raised, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.border, lineWidth: Theme.line(.thin)))
    }
}
