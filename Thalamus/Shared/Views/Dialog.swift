import SwiftUI

struct DialogHeading: View {
    let title: Text
    let subtitle: Text

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space(.s4)) {
            if Theme.style.boxes == .surfaces {
                title.font(Theme.font(.headline, weight: .semibold))
            }
            subtitle
                .font(Theme.font(.smallPlus))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(EdgeInsets(top: Theme.space(.s18), leading: Theme.space(.s20), bottom: Theme.space(.s4), trailing: Theme.space(.s20)))
        .preference(key: DialogTitleKey.self, value: title)
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
    static var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.radius(.r8), style: .continuous) }
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
                if Theme.style.marks == .characters {
                    Text(Style.checkbox(isOn)).foregroundStyle(isOn ? Theme.accent : Theme.textTertiary)
                } else {
                    box
                }
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

    private var box: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.radius(.r4), style: .continuous)
                .fill(isOn ? Theme.action : .clear)
            RoundedRectangle(cornerRadius: Theme.radius(.r4), style: .continuous)
                .strokeBorder(isOn ? Theme.action : Theme.borderControl, lineWidth: Theme.line(.medium))
            if isOn {
                Theme.image(.done, size: .mini, weight: .bold)
                    .foregroundStyle(Theme.onAction)
            }
        }
        .frame(width: Theme.size(.s16), height: Theme.size(.s16))
    }
}

struct DialogWarning<Actions: View>: View {
    let title: String
    let detail: String
    @ViewBuilder var actions: Actions

    var body: some View {
        HStack(spacing: Theme.space(.s10)) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.space(.s9)) {
                Theme.image(.warning, size: .small)
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

struct ConfirmationChoice {
    let title: String
    var isDestructive = false
    let action: () -> Void
}

extension View {
    func confirmation(_ title: String, isPresented: Binding<Bool>, message: String,
                      choices: [ConfirmationChoice]) -> some View {
        sheet(isPresented: isPresented) {
            ConfirmationDialog(title: title, message: message, choices: choices) { choice in
                choice?.action()
                isPresented.wrappedValue = false
            }
        }
    }
}

struct ConfirmationDialog: View {
    static let width: CGFloat = 260

    @State private var titleWhenOpened: String
    let message: String
    let choices: [ConfirmationChoice]
    var finish: (ConfirmationChoice?) -> Void

    init(title: String, message: String, choices: [ConfirmationChoice],
         finish: @escaping (ConfirmationChoice?) -> Void) {
        _titleWhenOpened = State(initialValue: title)
        self.message = message
        self.choices = choices
        self.finish = finish
    }

    static func defaultIndex(of choices: [ConfirmationChoice]) -> Int? {
        choices.firstIndex { !$0.isDestructive }
    }

    var body: some View {
        switch Theme.style.marks {
        case .graphic: surface
        case .characters: lines
        }
    }

    private var lines: some View {
        let options = choices.map(Optional.some) + [nil]
        return VStack(alignment: .leading, spacing: Theme.space(.s8)) {
            Text(message)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(Array(options.enumerated()), id: \.offset) { index, choice in
                ConfirmationLine(number: index + 1, title: choice?.title ?? "Cancelar",
                                 isDestructive: choice?.isDestructive ?? false,
                                 isDefault: choice != nil && index == Self.defaultIndex(of: choices)) {
                    finish(choice)
                }
                .keyboardShortcut(choice == nil ? KeyboardShortcut.cancelAction
                                  : index == Self.defaultIndex(of: choices) ? KeyboardShortcut.defaultAction : nil)
            }
        }
        .font(Theme.font(.body))
        .padding(Theme.space(.s12))
        .frame(width: Self.width + Theme.space(.s96))
        .titledCard(titleWhenOpened, border: Theme.borderStrong, accent: Theme.text)
        .background(FramelessWindow())
        .presentationBackground(.clear)
    }

    private var surface: some View {
        VStack(alignment: .leading, spacing: Theme.space(.s16)) {
            VStack(alignment: .leading, spacing: Theme.space(.s6)) {
                Text(titleWhenOpened)
                    .font(Theme.font(.body, weight: .bold))
                Text(message)
                    .font(Theme.font(.small))
                    .foregroundStyle(Theme.textSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            buttons
        }
        .padding(Theme.space(.s18))
        .frame(width: Self.width)
        .background(Theme.raised)
    }

    @ViewBuilder
    private var buttons: some View {
        let stacked = choices.count > 1
        let layout = stacked ? AnyLayout(VStackLayout(spacing: Theme.space(.s8)))
                             : AnyLayout(HStackLayout(spacing: Theme.space(.s8)))
        layout {
            if !stacked { cancel }
            ForEach(Array(choices.enumerated()), id: \.offset) { index, choice in
                choiceButton(choice, isDefault: index == Self.defaultIndex(of: choices))
            }
            if stacked { cancel }
        }
    }

    private var cancel: some View {
        Button { finish(nil) } label: { label("Cancelar") }
            .buttonStyle(.thalamusSecondary)
            .keyboardShortcut(.cancelAction)
    }

    @ViewBuilder
    private func choiceButton(_ choice: ConfirmationChoice, isDefault: Bool) -> some View {
        let button = Button { finish(choice) } label: { label(choice.title) }
            .buttonStyle(ThalamusButtonStyle(kind: choice.isDestructive ? .destructive
                                                 : isDefault ? .primary : .secondary))
        if isDefault {
            button.keyboardShortcut(.defaultAction)
        } else {
            button
        }
    }

    private func label(_ title: String) -> some View {
        Text(title)
            .font(Theme.font(.body, weight: .medium))
            .frame(maxWidth: .infinity)
            .frame(height: Theme.size(.s28))
    }
}

private struct ConfirmationLine: View {
    let number: Int
    let title: String
    let isDestructive: Bool
    let isDefault: Bool
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.space(.s8)) {
                Text(hovering || isDefault ? "❯" : " ").foregroundStyle(Theme.accent)
                Text("\(number).").foregroundStyle(Theme.textTertiary)
                Text(title).foregroundStyle(isDestructive ? Theme.removed : Theme.text)
                Spacer(minLength: 0)
            }
            .background(hovering ? Theme.hover : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(title)
    }
}

extension View {
    func dialogBox() -> some View {
        modifier(DialogBoxFrame())
    }
}

private struct DialogBoxFrame: ViewModifier {
    func body(content: Content) -> some View {
        switch Theme.style.boxes {
        case .surfaces:
            content
        case .lines:
            content
                .mask { Rectangle().padding(Theme.space(.s4)).padding(.top, LineBox.titleRoom) }
                .overlayPreferenceValue(DialogTitleKey.self) { title in
                    if let title {
                        LineBox(title: title, fill: Theme.canvas, tint: Theme.borderStrong, titleColor: Theme.text)
                            .padding(Theme.space(.s4))
                            .padding(.top, LineBox.titleRoom)
                            .allowsHitTesting(false)
                    }
                }
                .background(FramelessWindow())
                .presentationBackground(.clear)
        }
    }
}

private struct FramelessWindow: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { Clearing() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class Clearing: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            clear()
            DispatchQueue.main.async { [weak self] in self?.clear() }
        }

        override func layout() {
            super.layout()
            clear()
        }

        private func clear() {
            guard let window else { return }
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            for effect in window.contentView?.superview?.subviews ?? [] where effect is NSVisualEffectView {
                effect.isHidden = true
            }
        }
    }
}

struct DialogTitleKey: SwiftUI.PreferenceKey {
    static let defaultValue: Text? = nil

    static func reduce(value: inout Text?, nextValue: () -> Text?) {
        value = value ?? nextValue()
    }
}
