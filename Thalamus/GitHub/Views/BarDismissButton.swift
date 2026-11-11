import SwiftUI

struct BarDismissButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Theme.image(.close)
                .font(Theme.font(.label, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .iconLabel(size: .s24)
        }
        .buttonStyle(.thalamusGhost(radius: .r6))
        .accessibilityLabel("Dispensar")
    }
}
