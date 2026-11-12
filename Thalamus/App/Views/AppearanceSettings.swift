import SwiftUI

struct AppearanceSettings: View {
    let defaults: UserDefaults

    var body: some View {
        let style = Theme.style
        let palette = Theme.palette
        SettingsPage {
            SettingsSection(title: "Estilo") {
                ThemeOptions(options: Style.all) { option in
                    ThemeOption(name: option.name, isSelected: option.id == style.id,
                                preview: ThemePreview(style: option, palette: palette)) {
                        ThemeStore.shared.choose(option, in: defaults)
                    }
                }
            }
            SettingsSection(title: "Paleta") {
                ThemeOptions(options: Palette.all) { option in
                    ThemeOption(name: option.name, isSelected: option.id == palette.id,
                                preview: ThemePreview(style: style, palette: option)) {
                        ThemeStore.shared.choose(option, in: defaults)
                    }
                }
            }
            SettingsNote(text: "O Tema vale na hora, em todas as janelas.")
        }
    }
}

private struct ThemeOptions<Option: Identifiable, Tile: View>: View {
    let options: [Option]
    @ViewBuilder var tile: (Option) -> Tile

    var body: some View {
        HStack(spacing: Theme.space(.s12)) {
            ForEach(options) { tile($0) }
            Spacer(minLength: 0)
        }
        .padding(Theme.space(.s12))
    }
}

private struct ThemeOption: View {
    let name: String
    let isSelected: Bool
    let preview: ThemePreview
    var choose: () -> Void

    @State private var hovering = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radius(.r10), style: .continuous)
        Button(action: choose) {
            VStack(spacing: Theme.space(.s7)) {
                preview
                Text(name)
                    .font(Theme.font(.small, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.text : Theme.textSecondary)
            }
            .padding(Theme.space(.s6))
            .background(hovering && !isSelected ? Theme.hover : .clear, in: shape)
            .overlay(shape.strokeBorder(isSelected ? Theme.accent : .clear, lineWidth: Theme.line(.medium)))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct ThemePreview: View {
    let style: Style
    let palette: Palette

    static let width: CGFloat = 148
    static let height: CGFloat = 92

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: style.radius(.r8), style: .continuous)
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(palette.borders.border).frame(width: style.line(.thin))
            conversation
        }
        .frame(width: Self.width, height: Self.height)
        .background(palette.surfaces.canvas)
        .clipShape(shape)
        .overlay(shape.strokeBorder(palette.borders.strong, lineWidth: style.line(.thin)))
        .accessibilityHidden(true)
    }

    private var sidebar: some View {
        let states = palette.sessionStates
        return VStack(alignment: .leading, spacing: style.space(.s6)) {
            ForEach(Array([states.awaitingDecision, states.outOfTokens, states.newReply, states.thinking].enumerated()),
                    id: \.offset) { _, color in
                HStack(spacing: style.space(.s4)) {
                    Circle().fill(color).frame(width: style.size(.s5), height: style.size(.s5))
                    bar(palette.texts.tertiary, width: style.size(.s20))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(style.space(.s8))
        .frame(width: style.size(.s44), alignment: .leading)
        .frame(maxHeight: .infinity)
        .background(palette.surfaces.sidebar)
    }

    private var conversation: some View {
        VStack(alignment: .leading, spacing: style.space(.s5)) {
            Text("Aa")
                .font(style.font(.caption, .semibold, nil))
                .foregroundStyle(palette.texts.text)
            bar(palette.texts.secondary, width: style.size(.s56))
            HStack(spacing: style.space(.s3)) {
                bar(palette.changes.added, width: style.size(.s22))
                bar(palette.changes.removed, width: style.size(.s14))
                bar(palette.changes.modified, width: style.size(.s10))
            }
            Spacer(minLength: 0)
            HStack {
                Spacer(minLength: 0)
                Circle().fill(palette.accents.action).frame(width: style.size(.s10), height: style.size(.s10))
            }
            .padding(style.space(.s3))
            .background(palette.surfaces.field, in: RoundedRectangle(cornerRadius: style.radius(.r6), style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: style.radius(.r6), style: .continuous)
                .strokeBorder(palette.borders.control, lineWidth: style.line(.thin)))
        }
        .padding(style.space(.s8))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func bar(_ color: Color, width: CGFloat) -> some View {
        Capsule().fill(color).frame(width: width, height: style.size(.s3))
    }
}
