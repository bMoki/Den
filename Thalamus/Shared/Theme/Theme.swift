import SwiftUI

nonisolated enum Theme {
    static var palette: Palette { .current }

    static var canvas: Color { palette.surfaces.canvas }
    static var sidebar: Color { palette.surfaces.sidebar }
    static var panel: Color { palette.surfaces.panel }
    static var raised: Color { palette.surfaces.raised }
    static var field: Color { palette.surfaces.field }
    static var card: Color { palette.surfaces.card }
    static var bubble: Color { palette.surfaces.bubble }
    static var hover: Color { palette.surfaces.hover }
    static var hoverRaised: Color { palette.surfaces.hoverRaised }
    static var tip: Color { palette.surfaces.tip }
    static var terminal: Color { palette.surfaces.terminal }
    static var shadow: Color { palette.surfaces.shadow }
    static var scrim: Color { palette.surfaces.scrim }

    static var border: Color { palette.borders.border }
    static var borderCard: Color { palette.borders.card }
    static var borderStrong: Color { palette.borders.strong }
    static var borderControl: Color { palette.borders.control }

    static var text: Color { palette.texts.text }
    static var textSecondary: Color { palette.texts.secondary }
    static var textMuted: Color { palette.texts.muted }
    static var textTertiary: Color { palette.texts.tertiary }
    static var textFaint: Color { palette.texts.faint }
    static var input: Color { palette.texts.input }
    static var inlineCode: Color { palette.texts.inlineCode }
    static var onBadge: Color { palette.texts.onBadge }

    static var accent: Color { palette.accents.accent }
    static var accentSoft: Color { palette.accents.soft }
    static var accentFill: Color { palette.accents.fill }
    static var action: Color { palette.accents.action }
    static var onAction: Color { palette.accents.onAction }

    static var added: Color { palette.changes.added }
    static var addedFill: Color { palette.changes.addedFill }
    static var removed: Color { palette.changes.removed }
    static var removedFill: Color { palette.changes.removedFill }
    static var modified: Color { palette.changes.modified }
    static var renamed: Color { palette.changes.renamed }
    static var hunk: Color { palette.changes.hunk }
    static var hunkFill: Color { palette.changes.hunkFill }

    static var alertFill: Color { palette.alerts.fill }
    static var alertBorder: Color { palette.alerts.border }
    static var alertText: Color { palette.alerts.text }

    static let headerHeight: CGFloat = 52
    static let trafficLightsInset: CGFloat = 78
}

struct ThalamusButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, ghost, destructive }

    var kind: Kind
    var radius: CGFloat = 8

    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration, kind: kind, radius: radius)
    }

    private struct StyledLabel: View {
        let configuration: Configuration
        let kind: Kind
        let radius: CGFloat

        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            configuration.label
                .foregroundStyle(foreground)
                .background(background, in: shape)
                .overlay {
                    switch kind {
                    case .secondary: shape.strokeBorder(Theme.borderControl, lineWidth: 1)
                    case .destructive: shape.strokeBorder(Theme.removed.opacity(0.4), lineWidth: 1)
                    case .primary, .ghost: EmptyView()
                    }
                }
                .contentShape(shape)
                .opacity(isEnabled ? 1 : 0.45)
                .onHover { hovering = $0 }
                .animation(.easeOut(duration: 0.12), value: hovering)
        }

        private var foreground: Color {
            switch kind {
            case .primary: Theme.onAction
            case .secondary, .ghost: Theme.text
            case .destructive: Theme.removed
            }
        }

        private var background: Color {
            let active = isEnabled && (hovering || configuration.isPressed)
            switch kind {
            case .primary:
                return configuration.isPressed ? Theme.action.opacity(0.85)
                    : active ? Theme.accent : Theme.action
            case .secondary:
                return active ? Theme.hoverRaised : Theme.raised
            case .ghost:
                return configuration.isPressed ? Theme.hoverRaised
                    : active ? Theme.hover : .clear
            case .destructive:
                return active ? Theme.removed.opacity(0.28) : Theme.removedFill
            }
        }
    }
}

extension ButtonStyle where Self == ThalamusButtonStyle {
    static var thalamusPrimary: ThalamusButtonStyle { ThalamusButtonStyle(kind: .primary) }
    static var thalamusSecondary: ThalamusButtonStyle { ThalamusButtonStyle(kind: .secondary) }
    static var thalamusGhost: ThalamusButtonStyle { ThalamusButtonStyle(kind: .ghost) }
    static var thalamusDestructive: ThalamusButtonStyle { ThalamusButtonStyle(kind: .destructive) }
    static func thalamusGhost(radius: CGFloat) -> ThalamusButtonStyle {
        ThalamusButtonStyle(kind: .ghost, radius: radius)
    }
}

struct PillLabel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 14)
            .frame(height: 32)
    }
}

struct ChipLabel: ViewModifier {
    var horizontalPadding: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .font(.system(size: 12.5))
            .padding(.horizontal, horizontalPadding)
            .frame(height: 30)
            .contentShape(Rectangle())
    }
}

struct IconLabel: ViewModifier {
    var size: CGFloat = 30

    func body(content: Content) -> some View {
        content
            .frame(width: size, height: size)
            .contentShape(Rectangle())
    }
}

extension View {
    func pillLabel() -> some View { modifier(PillLabel()) }

    func iconLabel(size: CGFloat = 30) -> some View { modifier(IconLabel(size: size)) }

    func chipLabel(horizontalPadding: CGFloat = 10) -> some View {
        modifier(ChipLabel(horizontalPadding: horizontalPadding))
    }

    func onKeyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers,
                            perform action: @escaping () -> Void) -> some View {
        background {
            Button("", action: action)
                .keyboardShortcut(key, modifiers: modifiers)
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    func hoverFill(_ hovering: Bool = false, selected: Bool = false, radius: CGFloat = 8) -> some View {
        background(selected ? Theme.hover : hovering ? Theme.hover.opacity(0.7) : .clear,
                   in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

struct ChipSurface: ViewModifier {
    var bordered = false
    var radius: CGFloat = 8
    var hovering = false
    var open = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let active = hovering || open
        return content
            .background(bordered ? (active ? Theme.hoverRaised : Theme.raised)
                                 : (active ? Theme.hover : .clear), in: shape)
            .overlay {
                if bordered { shape.strokeBorder(Theme.borderStrong, lineWidth: 1) }
            }
    }
}

extension View {
    func chipSurface(bordered: Bool = false, radius: CGFloat = 8,
                     hovering: Bool = false, open: Bool = false) -> some View {
        modifier(ChipSurface(bordered: bordered, radius: radius,
                             hovering: hovering, open: open))
    }
}

struct BackButton: View {
    let title: String
    var back: () -> Void

    var body: some View {
        Button(action: back) {
            HStack(spacing: 5) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 9, weight: .semibold))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.textTertiary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Voltar")
    }
}

struct Chevron: View {
    var size: CGFloat = 9

    var body: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(Theme.textTertiary)
    }
}
