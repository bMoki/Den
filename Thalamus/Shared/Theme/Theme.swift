import SwiftUI

nonisolated enum Theme {
    static var palette: Palette { ThemeStore.shared.palette }
    static var style: Style { ThemeStore.shared.style }

    static func font(_ size: Style.TextSize, weight: Font.Weight? = nil, design: Font.Design? = nil) -> Font {
        style.font(size, weight, design)
    }

    static func inlineCodeFont(_ size: Style.TextSize, weight: Font.Weight? = nil) -> Font {
        style.inlineCodeFont(size, weight)
    }

    static func font(fitting box: CGFloat, weight: Font.Weight? = nil) -> Font { style.boxFont(box, weight) }
    static func nsFont(_ size: Style.TextSize) -> NSFont { style.nsFont(size) }
    static func nsCodeFont(_ size: Style.TextSize) -> NSFont { style.nsCodeFont(size) }
    static func radius(_ radius: Style.Radius) -> CGFloat { style.radius(radius) }
    static func radius(fitting box: CGFloat) -> CGFloat { style.boxRadius(box) }
    static func line(_ line: Style.Line) -> CGFloat { style.line(line) }
    static func space(_ space: Style.Space) -> CGFloat { style.space(space) }
    static func size(_ size: Style.Size) -> CGFloat { style.size(size) }
    static func image(_ icon: Icon) -> Image { style.image(icon) }
    static func nsImage(_ icon: Icon) -> NSImage? { style.nsImage(icon) }

    static var canvas: Color { palette.surfaces.canvas }
    static var sidebar: Color { flat(palette.surfaces.sidebar) }
    static var panel: Color { flat(palette.surfaces.panel) }
    static var raised: Color { flat(palette.surfaces.raised) }
    static var field: Color { flat(palette.surfaces.field) }
    static var card: Color { flat(palette.surfaces.card) }
    static var bubble: Color { flat(palette.surfaces.bubble) }
    static var hover: Color { palette.surfaces.hover }
    static var hoverRaised: Color { style.boxes == .lines ? palette.surfaces.hover : palette.surfaces.hoverRaised }
    static var tip: Color { palette.surfaces.tip }
    static var terminal: Color { flat(palette.surfaces.terminal) }
    static var shadow: Color { palette.surfaces.shadow }
    static var scrim: Color { palette.surfaces.scrim }

    private static func flat(_ surface: Color) -> Color {
        style.boxes == .lines ? palette.surfaces.canvas : surface
    }

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

    static var alertFill: Color { flat(palette.alerts.fill) }
    static var alertBorder: Color { palette.alerts.border }
    static var alertText: Color { palette.alerts.text }

    static let headerHeight: CGFloat = 52
    static let trafficLightsInset: CGFloat = 78
}

struct ThalamusButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, ghost, destructive }

    var kind: Kind
    var radius: Style.Radius = .r8
    var tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        StyledLabel(configuration: configuration, kind: kind, radius: radius, tint: tint)
    }

    private struct StyledLabel: View {
        let configuration: Configuration
        let kind: Kind
        let radius: Style.Radius
        let tint: Color?

        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            switch Theme.style.marks {
            case .graphic: surface
            case .characters: bracketed
            }
        }

        private var bracketed: some View {
            configuration.label
                .bracketed(kind != .ghost)
                .padding(.horizontal, kind == .ghost ? Theme.space(.s4) : 0)
                .foregroundStyle(tint ?? (kind == .primary ? Theme.accent : foreground))
                .background(isEnabled && (hovering || configuration.isPressed) ? Theme.hover : .clear)
                .contentShape(Rectangle())
                .opacity(isEnabled ? 1 : 0.45)
                .onHover { hovering = $0 }
        }

        private var surface: some View {
            let shape = RoundedRectangle(cornerRadius: Theme.radius(radius), style: .continuous)
            return configuration.label
                .foregroundStyle(tint ?? foreground)
                .background(background, in: shape)
                .overlay {
                    switch kind {
                    case .secondary: shape.strokeBorder(Theme.borderControl, lineWidth: Theme.line(.thin))
                    case .destructive: shape.strokeBorder(Theme.removed.opacity(0.4), lineWidth: Theme.line(.thin))
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
    static func thalamusGhost(radius: Style.Radius) -> ThalamusButtonStyle {
        ThalamusButtonStyle(kind: .ghost, radius: radius)
    }
}

struct PillLabel: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(Theme.font(.body, weight: .medium))
            .padding(.horizontal, Theme.style.marks == .characters ? 0 : Theme.space(.s14))
            .frame(height: Theme.size(.s32))
    }
}

struct ChipLabel: ViewModifier {
    var horizontalPadding: Style.Space = .s10

    func body(content: Content) -> some View {
        content
            .font(Theme.font(.smallPlus))
            .padding(.horizontal, Theme.style.marks == .characters ? 0 : Theme.space(horizontalPadding))
            .frame(height: Theme.size(.s30))
            .contentShape(Rectangle())
    }
}

struct IconLabel: ViewModifier {
    var size: Style.Size = .s30

    func body(content: Content) -> some View {
        content
            .frame(width: Theme.style.marks == .characters ? nil : Theme.size(size), height: Theme.size(size))
            .contentShape(Rectangle())
    }
}

extension View {
    func pillLabel() -> some View { modifier(PillLabel()) }

    func iconLabel(size: Style.Size = .s30) -> some View { modifier(IconLabel(size: size)) }

    func chipLabel(horizontalPadding: Style.Space = .s10) -> some View {
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

    func hoverFill(_ hovering: Bool = false, selected: Bool = false, radius: Style.Radius = .r8) -> some View {
        background(selected ? Theme.hover : hovering ? Theme.hover.opacity(0.7) : .clear,
                   in: RoundedRectangle(cornerRadius: Theme.radius(radius), style: .continuous))
    }
}

extension View {
    func card(border: Color = Theme.borderCard) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radius(.r12), style: .continuous)
        return background(Theme.card, in: shape)
            .overlay(shape.strokeBorder(border, lineWidth: Theme.line(.thin)))
    }
}

struct ChipSurface: ViewModifier {
    var bordered = false
    var radius: Style.Radius = .r8
    var hovering = false
    var open = false

    func body(content: Content) -> some View {
        switch Theme.style.marks {
        case .graphic: surface(content)
        case .characters:
            content
                .bracketed(bordered)
                .background(hovering || open ? Theme.hover : .clear)
        }
    }

    private func surface(_ content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radius(radius), style: .continuous)
        let active = hovering || open
        return content
            .background(bordered ? (active ? Theme.hoverRaised : Theme.raised)
                                 : (active ? Theme.hover : .clear), in: shape)
            .overlay {
                if bordered { shape.strokeBorder(Theme.borderStrong, lineWidth: Theme.line(.thin)) }
            }
    }
}

extension View {
    func chipSurface(bordered: Bool = false, radius: Style.Radius = .r8,
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
            HStack(spacing: Theme.space(.s5)) {
                Theme.image(.back)
                    .font(Theme.font(.mini, weight: .semibold))
                Text(title)
                    .font(Theme.font(.label, weight: .semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.textTertiary)
            .padding(.horizontal, Theme.space(.s10))
            .padding(.vertical, Theme.space(.s4))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Voltar")
    }
}

struct Swatch: View {
    let color: Color?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radius(.r3), style: .continuous)
        Group {
            if let color {
                shape.fill(color)
            } else {
                shape.strokeBorder(Theme.textFaint, lineWidth: Theme.line(.thin))
            }
        }
        .frame(width: Theme.size(.s10), height: Theme.size(.s10))
    }
}

struct Chevron: View {
    var size: Style.TextSize = .mini

    @Environment(\.isBracketed) private var isBracketed

    var body: some View {
        Theme.image(.expanded)
            .font(Theme.font(size, weight: .semibold))
            .foregroundStyle(isBracketed ? AnyShapeStyle(.foreground) : AnyShapeStyle(Theme.textTertiary))
    }
}

extension Label where Title == Text, Icon == Image {
    init(_ title: some StringProtocol, icon: Thalamus.Icon) {
        self.init { Text(title) } icon: { Theme.image(icon) }
    }
}

struct RoundShape: InsettableShape {
    enum Kind { case capsule, circle }

    let kind: Kind
    let squared: Bool
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let box = rect.insetBy(dx: inset, dy: inset)
        if squared { return Path(box) }
        switch kind {
        case .capsule: return Capsule().path(in: box)
        case .circle: return Circle().path(in: box)
        }
    }

    func inset(by amount: CGFloat) -> RoundShape {
        RoundShape(kind: kind, squared: squared, inset: inset + amount)
    }
}

extension Theme {
    static var capsule: RoundShape { RoundShape(kind: .capsule, squared: style.boxes == .lines) }
    static var circle: RoundShape { RoundShape(kind: .circle, squared: style.boxes == .lines) }
}

private struct Bracketed: ViewModifier {
    let isFramed: Bool

    func body(content: Content) -> some View {
        switch Theme.style.marks {
        case .graphic:
            content
        case .characters where !isFramed:
            content
        case .characters:
            HStack(spacing: 0) {
                Text("[").accessibilityHidden(true)
                content.environment(\.isBracketed, true)
                Text("]").accessibilityHidden(true)
            }
            .font(Theme.font(.body))
        }
    }
}

extension EnvironmentValues {
    @Entry var isBracketed = false
}

extension View {
    func bracketed(_ isFramed: Bool = true) -> some View { modifier(Bracketed(isFramed: isFramed)) }
}
