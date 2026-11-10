import SwiftUI

struct BarDismissButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .iconLabel(size: 24)
        }
        .buttonStyle(.thalamusGhost(radius: 6))
        .accessibilityLabel("Dispensar")
    }
}
