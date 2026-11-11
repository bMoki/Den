import SwiftUI

struct DisclosureChevron: View {
    let isOpen: Bool

    var body: some View {
        Theme.image(.next)
            .font(Theme.font(.label, weight: .semibold))
            .foregroundStyle(Theme.textTertiary)
            .rotationEffect(.degrees(isOpen ? 90 : 0))
            .frame(width: Theme.size(.s12))
    }
}

struct SessionCountLabel: View {
    enum Noun {
        case sessions, hiddenRows

        func describe(_ count: Int) -> String {
            switch self {
            case .sessions: count == 1 ? "1 sessão" : "\(count) sessões"
            case .hiddenRows: count == 1 ? "1 linha escondida" : "\(count) linhas escondidas"
            }
        }
    }

    let count: Int
    var noun = Noun.sessions

    var body: some View {
        Text("\(count)")
            .font(Theme.font(.caption))
            .monospacedDigit()
            .foregroundStyle(Theme.textTertiary)
            .accessibilityLabel(noun.describe(count))
    }
}

struct SessionTallyLabel: View {
    let sessions: SessionTally

    var body: some View {
        if let prevailing = sessions.prevailing {
            HStack(spacing: Theme.space(.s5)) {
                SessionStateMark(state: prevailing.state)
                SessionCountLabel(count: prevailing.count)
            }
            .describedAs(prevailing.label)
        } else if sessions.total > 0 {
            SessionCountLabel(count: sessions.total)
        }
    }
}

struct SidebarSectionTitle<Trailing: View>: View {
    struct Expansion {
        let isExpanded: Bool
        let isEnabled: Bool
        let toggle: () -> Void
    }

    let title: String
    var expansion: Expansion?
    @ViewBuilder var trailing: () -> Trailing

    init(_ title: String, expansion: Expansion? = nil, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.expansion = expansion
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: Theme.space(.s4)) {
            if let expansion {
                Button(action: expansion.toggle) { label.contentShape(Rectangle()) }
                    .buttonStyle(.plain)
                    .disabled(!expansion.isEnabled)
                    .accessibilityLabel(title)
                    .accessibilityValue(expansion.isExpanded ? "expandido" : "encolhido")
            } else {
                label
            }
            HStack(spacing: Theme.space(.s4), content: trailing)
                .fixedSize()
        }
        .padding(.leading, Theme.space(.s10))
        .padding(.trailing, Theme.space(.s4))
        .frame(height: Theme.size(.s28))
    }

    private var label: some View {
        HStack(spacing: Theme.space(.s4)) {
            Text(title)
                .font(Theme.font(.small, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
    }
}

struct SidebarCollapsibleTitle<Actions: View>: View {
    let title: String
    let hidden: Int
    let isExpanded: Bool
    let isEnabled: Bool
    var toggle: () -> Void
    @ViewBuilder var actions: () -> Actions

    var body: some View {
        SidebarSectionTitle(title, expansion: .init(isExpanded: isExpanded, isEnabled: isEnabled,
                                                    toggle: animatedToggle)) {
            actions()
            Button(action: animatedToggle) {
                HStack(spacing: Theme.space(.s4)) {
                    ZStack(alignment: .trailing) {
                        Text("999").font(Theme.font(.caption)).monospacedDigit().hidden()
                        SessionCountLabel(count: hidden, noun: .hiddenRows)
                            .opacity(hidden > 0 ? 1 : 0)
                    }
                    DisclosureChevron(isOpen: isExpanded)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .focusable(false)
            .accessibilityHidden(true)
        }
    }

    private func animatedToggle() {
        withAnimation(.easeInOut(duration: 0.22)) { toggle() }
    }
}

enum FavoriteTitle {
    static let add = "Favoritar"
    static let remove = "Remover dos favoritos"

    static func item(isFavorite: Bool, toggle: @escaping () -> Void) -> ThalamusMenuItem {
        ThalamusMenuItem(id: "favorite", title: isFavorite ? remove : add, action: toggle)
    }
}

extension View {
    func sidebarHeaderRow(hovering: Binding<Bool>, isSelected: Bool, open: @escaping () -> Void) -> some View {
        hoverFill(hovering.wrappedValue, selected: isSelected)
            .contentShape(Rectangle())
            .onHover { hovering.wrappedValue = $0 }
            .onTapGesture(perform: open)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct ArchivedRow: View {
    let count: Int
    let isSelected: Bool
    var open: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: Theme.space(.s8)) {
            Theme.image(.archive)
                .font(Theme.font(.small))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: Theme.size(.s16))
            Text(SidebarRow.archivedTitle)
                .font(Theme.font(.body, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: Theme.space(.s4))
            SessionCountLabel(count: count)
        }
        .padding(.horizontal, Theme.space(.s10))
        .frame(height: Theme.size(.s32))
        .sidebarHeaderRow(hovering: $hovering, isSelected: isSelected, open: open)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}
