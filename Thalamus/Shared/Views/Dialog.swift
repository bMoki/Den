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

struct DialogCancelButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) { Text("Cancelar").pillLabel() }
            .buttonStyle(.thalamusSecondary)
            .keyboardShortcut(.cancelAction)
    }
}

extension View {
    func dialogField(focused: Bool, design: Font.Design = .monospaced) -> some View {
        textFieldStyle(.plain)
            .font(.system(size: 13, design: design))
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(Theme.field, in: DialogBox.shape)
            .overlay(DialogBox.shape.strokeBorder(focused ? Theme.accent.opacity(0.7) : Theme.borderControl))
    }
}

struct DialogNameField: View {
    @Binding var name: String
    var accessibilityLabel: String
    var submit: () -> Void

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nome")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            TextField("", text: $name)
                .focused($focused)
                .onSubmit(submit)
                .dialogField(focused: focused)
                .accessibilityLabel(accessibilityLabel)
        }
        .onAppear { focused = true }
    }
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

struct DialogWarning<Actions: View>: View {
    let title: String
    let detail: String
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 9) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 12))
                Text("\(title) \(Text(detail).foregroundStyle(Theme.alertText.opacity(0.8)))")
                    .font(.system(size: 12.5))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            actions
        }
        .foregroundStyle(Theme.alertText)
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.alertFill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.alertBorder))
    }
}

extension DialogWarning where Actions == EmptyView {
    init(title: String, detail: String) {
        self.init(title: title, detail: detail) { EmptyView() }
    }
}
