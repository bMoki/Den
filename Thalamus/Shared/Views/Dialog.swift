import SwiftUI

struct DialogHeading: View {
    let title: Text
    let subtitle: Text

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space(.s4)) {
            title.font(Theme.font(.headline, weight: .semibold))
            subtitle
                .font(Theme.font(.smallPlus))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(EdgeInsets(top: Theme.space(.s18), leading: Theme.space(.s20), bottom: Theme.space(.s4), trailing: Theme.space(.s20)))
    }
}

struct DialogFooter<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: Theme.space(.s8)) {
            content()
        }
        .padding(EdgeInsets(top: Theme.space(.s14), leading: Theme.space(.s20), bottom: Theme.space(.s18), trailing: Theme.space(.s20)))
    }
}

enum DialogBox {
    static let shape = RoundedRectangle(cornerRadius: Theme.radius(.r8), style: .continuous)
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
    func dialogBody() -> some View {
        padding(EdgeInsets(top: Theme.space(.s14), leading: Theme.space(.s20),
                           bottom: Theme.space(.s4), trailing: Theme.space(.s20)))
    }

    func dialogField(focused: Bool, design: Font.Design = .monospaced) -> some View {
        textFieldStyle(.plain)
            .font(Theme.font(.body, design: design))
            .padding(.horizontal, Theme.space(.s11))
            .frame(height: Theme.size(.s34))
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
        VStack(alignment: .leading, spacing: Theme.space(.s8)) {
            Text("Nome")
                .font(Theme.font(.small, weight: .medium))
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
            HStack(spacing: Theme.space(.s9)) {
                ZStack {
                    RoundedRectangle(cornerRadius: Theme.radius(.r4), style: .continuous)
                        .fill(isOn ? Theme.action : .clear)
                    RoundedRectangle(cornerRadius: Theme.radius(.r4), style: .continuous)
                        .strokeBorder(isOn ? Theme.action : Theme.borderControl, lineWidth: Theme.line(.medium))
                    if isOn {
                        Theme.image(.done)
                            .font(Theme.font(.mini, weight: .bold))
                            .foregroundStyle(Theme.onAction)
                    }
                }
                .frame(width: Theme.size(.s16), height: Theme.size(.s16))
                Text(title)
                    .font(Theme.font(.smallPlus, design: .monospaced))
                Spacer(minLength: 0)
                if let note {
                    Text(note)
                        .font(Theme.font(.caption))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(.horizontal, Theme.space(.s10))
            .frame(height: Theme.size(.s34))
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
        HStack(spacing: Theme.space(.s10)) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.space(.s9)) {
                Theme.image(.warning)
                    .font(Theme.font(.small))
                Text("\(title) \(Text(detail).foregroundStyle(Theme.alertText.opacity(0.8)))")
                    .font(Theme.font(.smallPlus))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            actions
        }
        .foregroundStyle(Theme.alertText)
        .padding(EdgeInsets(top: Theme.space(.s10), leading: Theme.space(.s12), bottom: Theme.space(.s10), trailing: Theme.space(.s12)))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.alertFill, in: RoundedRectangle(cornerRadius: Theme.radius(.r10), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius(.r10), style: .continuous).strokeBorder(Theme.alertBorder))
    }
}

extension DialogWarning where Actions == EmptyView {
    init(title: String, detail: String) {
        self.init(title: title, detail: detail) { EmptyView() }
    }
}
