import AppKit
import SwiftUI

struct LocationChip: View {
    let chat: ChatModel
    var compact: Bool

    var body: some View {
        Button(action: chooseSessionFolder) {
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.system(size: 12))
                if !compact {
                    Text(chat.workingDirectory.lastPathComponent)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 160)
                }
                Chevron(size: 8)
            }
            .foregroundStyle(Theme.textSecondary)
            .chipLabel()
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Theme.borderStrong, lineWidth: 1))
        }
        .buttonStyle(.thalamusGhost)
        .fixedSize()
        .help(chat.workingDirectory.path)
        .accessibilityLabel("Pasta da sessão: \(chat.workingDirectory.lastPathComponent)")
    }

    private func chooseSessionFolder() {
        guard let url = FolderPicker.choose(prompt: "Usar", from: chat.workingDirectory) else { return }
        Task { await chat.choose(directory: url) }
    }
}
