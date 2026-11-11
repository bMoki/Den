import SwiftUI

struct ComposerStatusChip: View {
    let chat: ChatModel
    let keys: ChatKeyMonitor

    var body: some View {
        let waiting = chat.pending != nil || chat.pendingQuestion != nil
        let interrupting = chat.isBusy && keys.escArmed
        if !waiting, interrupting || (!chat.isBusy && visibleStatus != nil) {
            HStack(spacing: Theme.space(.s7)) {
                if interrupting {
                    Theme.image(.escape)
                        .foregroundStyle(Theme.accentSoft)
                    Text("Esc de novo interrompe")
                } else if let status = visibleStatus {
                    Theme.image(.strongWarning)
                        .foregroundStyle(Theme.modified)
                    Text(status)
                        .lineLimit(1)
                }
            }
            .transition(.opacity)
            .font(Theme.font(.captionPlus, weight: .medium))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, Theme.space(.s10))
            .frame(height: Theme.size(.s24))
            .background(Theme.canvas.opacity(0.92), in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.borderStrong, lineWidth: Theme.line(.thin)))
            .fixedSize()
            .offset(x: Theme.space(.s10), y: -Theme.space(.s30))
            .allowsHitTesting(false)
        }
    }

    private var visibleStatus: String? {
        let status = chat.status
        guard status.hasPrefix("falhou") || status.hasPrefix("encerrada") else { return nil }
        return status.prefix(1).uppercased() + status.dropFirst()
    }
}
