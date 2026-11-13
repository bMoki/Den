import SwiftUI

struct ArchivedSessionBar: View {
    let branch: String

    var body: some View {
        HStack(spacing: Theme.space(.s10)) {
            Theme.image(.archive, size: .large)
                .foregroundStyle(Theme.textTertiary)
            Text("Sessão arquivada. A branch \(name) foi removida; o histórico continua legível, mas não aceita novas mensagens.")
                .font(Theme.font(.body))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(EdgeInsets(top: Theme.space(.s12), leading: Theme.space(.s14), bottom: Theme.space(.s12), trailing: Theme.space(.s14)))
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.radius(.r14), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius(.r14), style: .continuous).strokeBorder(Theme.border))
        .accessibilityElement(children: .combine)
        .composerColumn()
    }

    private var name: Text {
        Text(branch).font(Theme.font(.small, design: .monospaced)).foregroundStyle(Theme.text)
    }
}
