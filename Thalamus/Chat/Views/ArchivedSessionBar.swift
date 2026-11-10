import SwiftUI

struct ArchivedSessionBar: View {
    let branch: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "archivebox")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textTertiary)
            Text("Sessão arquivada. A branch \(name) foi removida; o histórico continua legível, mas não aceita novas mensagens.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.border))
        .accessibilityElement(children: .combine)
        .padding(.horizontal, 32)
        .padding(.top, 6)
        .padding(.bottom, 20)
        .frame(maxWidth: 784)
        .frame(maxWidth: .infinity)
    }

    private var name: Text {
        Text(branch).font(.system(size: 12, design: .monospaced)).foregroundStyle(Theme.text)
    }
}
