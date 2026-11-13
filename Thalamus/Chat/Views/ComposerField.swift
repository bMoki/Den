import SwiftUI

struct ComposerField: View {
    @Bindable var chat: ChatModel
    @Binding var focusRequested: Bool
    let placeholder: String
    var submit: () -> Void
    var stickToBottom: () -> Void

    var body: some View {
        ComposerTextView(text: $chat.prompt, focusRequested: $focusRequested,
                         placeholder: placeholder,
                         ghost: chat.visibleSuggestion ?? "",
                         onSubmit: submit,
                         onPaste: { chat.capturePaste($0) },
                         onAcceptGhost: acceptSuggestion,
                         onDismissGhost: chat.dismissSuggestion,
                         onTakeGhost: chat.takeSuggestion,
                         history: ComposerHistoryKeys(
                            isBrowsing: chat.isBrowsingHistory,
                            canGoOlder: { chat.canRecallOlder },
                            older: { Task { await chat.recallOlder() } },
                            newer: chat.recallNewer))
            .overlay(alignment: .topLeading) {
                if let suggestion = chat.visibleSuggestion {
                    suggestedReply(suggestion)
                        .transition(.opacity)
                } else if chat.prompt.isEmpty {
                    Text(placeholder)
                        .font(Theme.font(.large))
                        .foregroundStyle(Theme.textTertiary)
                        .allowsHitTesting(false)
                }
            }
            .animation(.easeOut(duration: 0.2), value: chat.visibleSuggestion)
    }

    private func suggestedReply(_ suggestion: String) -> some View {
        Text(suggestion)
            .font(Font(ComposerTextView.font))
            .foregroundStyle(Theme.textTertiary)
            .lineLimit(ComposerTextView.ghostMaxLines)
            .padding(.trailing, ComposerTextView.ghostTrailing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .allowsHitTesting(false)
            .accessibilityLabel("Resposta sugerida: \(suggestion). Tab coloca para editar, seta para a direita envia.")
            .accessibilityIdentifier("suggested-reply")
            .overlay(alignment: .topTrailing) {
                Button(action: acceptSuggestion) {
                    Theme.image(.submit, size: .label, weight: .semibold)
                        .foregroundStyle(Theme.textSecondary)
                        .iconLabel(size: .s20)
                        .overlay(RoundedRectangle(cornerRadius: Theme.radius(.r5), style: .continuous)
                            .strokeBorder(Theme.borderStrong, lineWidth: Theme.line(.thin)))
                }
                .buttonStyle(.thalamusGhost(radius: .r5))
                .tip("Enviar resposta sugerida", shortcut: "→")
                .accessibilityLabel("Enviar resposta sugerida")
            }
    }

    private func acceptSuggestion() {
        stickToBottom()
        Task { await chat.acceptSuggestion() }
    }
}
