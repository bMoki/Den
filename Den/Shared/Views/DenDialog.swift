import SwiftUI

struct DialogHeading: View {
    let title: Text
    let subtitle: Text

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            title.font(.system(size: 15, weight: .semibold))
            subtitle
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(EdgeInsets(top: 18, leading: 20, bottom: 4, trailing: 20))
    }
}

struct DialogFooter<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 8) {
            content()
        }
        .padding(EdgeInsets(top: 14, leading: 20, bottom: 18, trailing: 20))
    }
}

enum DialogBox {
    static let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
}

struct DialogCheckbox: View {
    let title: String
    @Binding var isOn: Bool
    var note: String?
    var isFixed = false

    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isOn ? Theme.action : .clear)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(isOn ? Theme.action : Theme.borderControl, lineWidth: 1.5)
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.onAction)
                    }
                }
                .frame(width: 16, height: 16)
                Text(title)
                    .font(.system(size: 12.5, design: .monospaced))
                Spacer(minLength: 0)
                if let note {
                    Text(note)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(Theme.card, in: DialogBox.shape)
            .overlay(DialogBox.shape.strokeBorder(Theme.border))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFixed)
        .opacity(isFixed ? 0.6 : 1)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "marcado" : "desmarcado")
        .accessibilityAddTraits(.isToggle)
    }
}
