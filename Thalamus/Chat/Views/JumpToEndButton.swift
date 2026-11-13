import SwiftUI

struct JumpToEndButton: View {
    var isVisible: Bool
    var action: () -> Void

    var body: some View {
        Group {
            if isVisible {
                Button(action: action) {
                    Theme.image(.jumpToEnd, size: .body, weight: .semibold)
                        .bracketed()
                        .foregroundStyle(Theme.text)
                        .frame(width: Theme.size(.s34), height: Theme.size(.s34))
                        .background(Theme.raised, in: Theme.circle)
                        .overlay(Theme.circle.strokeBorder(Theme.borderControl, lineWidth: Theme.line(.thin)))
                        .elevation(.floatingButton)
                }
                .buttonStyle(.plain)
                .padding(.bottom, Theme.space(.s14))
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                .tip("Ir para o final")
                .accessibilityLabel("Ir para o final")
            }
        }
        .animation(.easeOut(duration: 0.15), value: isVisible)
    }
}
