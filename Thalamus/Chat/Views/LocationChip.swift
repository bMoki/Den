import AppKit
import SwiftUI

struct LocationChip: View {
    let chat: ChatModel
    var compact: Bool

    var body: some View {
        Button(action: chooseSessionFolder) {
            HStack(spacing: Theme.space(.s6)) {
                Theme.image(.folder)
                    .font(Theme.font(.small))
                if !compact {
                    Text(chat.workingDirectory.lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 160)
                }
                Chevron(size: .tiny)
            }
            .chipLabel()
            .bracketed()
            .foregroundStyle(Theme.textSecondary)
            .overlay(RoundedRectangle(cornerRadius: Theme.radius(.r8), style: .continuous)
                .strokeBorder(Theme.style.marks == .characters ? .clear : Theme.borderStrong, lineWidth: Theme.line(.thin)))
        }
        .buttonStyle(.thalamusGhost)
        .fixedSize()
        .tip(chat.workingDirectory.path)
        .accessibilityLabel("Pasta da sessão: \(chat.workingDirectory.lastPathComponent)")
    }

    private func chooseSessionFolder() {
        guard let url = FolderPicker.choose(prompt: "Usar", from: chat.workingDirectory) else { return }
        Task { await chat.choose(directory: url) }
    }
}
