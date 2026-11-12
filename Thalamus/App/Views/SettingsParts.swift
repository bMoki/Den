import SwiftUI

struct SettingsPage<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space(.s20)) {
            content
        }
        .padding(Theme.space(.s20))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsSection<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space(.s7)) {
            if let title, Theme.style.boxes == .surfaces {
                Text(title)
                    .font(Theme.font(.small, weight: .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.leading, Theme.space(.s4))
            }
            VStack(alignment: .leading, spacing: 0) {
                Group(subviews: content) { rows in
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 {
                            Rectangle()
                                .fill(Theme.border)
                                .frame(height: Theme.line(.thin))
                                .padding(.horizontal, Theme.space(.s12))
                        }
                        row
                    }
                }
            }
            .titledCard(title, border: Theme.borderCard)
        }
    }
}

struct SettingsRow<Control: View>: View {
    let title: String
    @ViewBuilder var control: Control

    var body: some View {
        HStack(spacing: Theme.space(.s12)) {
            Text(title)
                .foregroundStyle(Theme.text)
                .lineLimit(1)
            Spacer(minLength: Theme.space(.s12))
            control
        }
        .font(Theme.font(.body))
        .padding(.horizontal, Theme.space(.s12))
        .frame(minHeight: Theme.size(.s40))
    }
}

struct SettingsNote: View {
    let text: String
    var color = Theme.textTertiary

    var body: some View {
        Text(text)
            .font(Theme.font(.caption))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Theme.space(.s12))
            .padding(.vertical, Theme.space(.s10))
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .settingsControl()
                .fontWeight(.medium)
        }
        .buttonStyle(.settingsControl)
    }
}

struct SettingsField: View {
    let label: String
    @Binding var text: String
    var prompt: String
    var submit: () -> Void = {}

    @FocusState private var focused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radius(SettingsControl.radius), style: .continuous)
        TextField(label, text: $text, prompt: Text(prompt).foregroundStyle(Theme.textFaint))
            .labelsHidden()
            .textFieldStyle(.plain)
            .focused($focused)
            .onSubmit(submit)
            .settingsControl()
            .font(Theme.font(.small, design: .monospaced))
            .background(Theme.field, in: shape)
            .overlay(shape.strokeBorder(focused ? Theme.accent.opacity(0.7) : Theme.borderControl,
                                        lineWidth: Theme.line(.thin)))
            .accessibilityLabel(label)
    }
}

struct SettingsChoice<Value: Hashable>: View {
    let options: [Value]
    @Binding var selection: Value
    var title: (Value) -> String

    var body: some View {
        switch Theme.style.marks {
        case .graphic: segments
        case .characters:
            if let index = options.firstIndex(of: selection) { arrows(at: index) }
        }
    }

    private func arrows(at index: Int) -> some View {
        HStack(spacing: Theme.space(.s4)) {
            arrow("‹", to: index - 1)
            Text(title(selection)).foregroundStyle(Theme.accent)
            arrow("›", to: index + 1)
        }
        .font(Theme.font(.body))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(options.map(title).joined(separator: ", "))
        .accessibilityValue(title(selection))
        .accessibilityAdjustableAction { direction in
            selection = options[(index + (direction == .increment ? 1 : options.count - 1)) % options.count]
        }
    }

    private func arrow(_ mark: String, to index: Int) -> some View {
        Button { selection = options[(index + options.count) % options.count] } label: {
            Text(mark).foregroundStyle(Theme.textTertiary).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var segments: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radius(.r7), style: .continuous)
        return HStack(spacing: Theme.space(.s2)) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button { selection = option } label: {
                    Text(title(option))
                        .font(Theme.font(.small, weight: .medium))
                        .foregroundStyle(isSelected ? Theme.text : Theme.textSecondary)
                        .padding(.horizontal, Theme.space(.s12))
                        .frame(height: Theme.size(.s22))
                        .background(isSelected ? Theme.hoverRaised : .clear,
                                    in: RoundedRectangle(cornerRadius: Theme.radius(.r5), style: .continuous))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(Theme.space(.s2))
        .background(Theme.field, in: shape)
        .overlay(shape.strokeBorder(Theme.borderControl, lineWidth: Theme.line(.thin)))
    }
}

struct SettingsMenu<Label: View>: View {
    let sections: [ThalamusMenuSection]
    @ViewBuilder var label: Label

    var body: some View {
        ThalamusMenuChip(sections: sections, bordered: true, radius: SettingsControl.radius, arrowEdge: .bottom) {
            HStack(spacing: Theme.space(.s6)) {
                label
                Chevron()
            }
            .foregroundStyle(Theme.text)
            .settingsControl()
        }
    }
}

enum SettingsControl {
    static let radius = Style.Radius.r6
}

extension View {
    func settingsControl() -> some View {
        font(Theme.font(.small))
            .padding(.horizontal, Theme.space(.s8))
            .frame(height: Theme.size(.s26))
            .contentShape(Rectangle())
    }
}

extension ButtonStyle where Self == ThalamusButtonStyle {
    static var settingsControl: ThalamusButtonStyle { ThalamusButtonStyle(kind: .secondary, radius: SettingsControl.radius) }
}
