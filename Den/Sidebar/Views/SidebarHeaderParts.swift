import SwiftUI

struct DisclosureChevron: View {
    let isOpen: Bool

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Theme.textTertiary)
            .rotationEffect(.degrees(isOpen ? 90 : 0))
            .frame(width: 12)
    }
}

struct SessionCountLabel: View {
    enum Noun {
        case sessions, favorites

        func describe(_ count: Int) -> String {
            switch self {
            case .sessions: count == 1 ? "1 sessão" : "\(count) sessões"
            case .favorites: count == 1 ? "1 favorito" : "\(count) favoritos"
            }
        }
    }

    let count: Int
    var noun = Noun.sessions

    var body: some View {
        Text("\(count)")
            .font(.system(size: 11))
            .monospacedDigit()
            .foregroundStyle(Theme.textTertiary)
            .accessibilityLabel(noun.describe(count))
    }
}

struct SessionTallyLabel: View {
    let sessions: SessionTally

    var body: some View {
        if let prevailing = sessions.prevailing {
            HStack(spacing: 5) {
                SessionStateDot(state: prevailing.state)
                SessionCountLabel(count: prevailing.count)
            }
            .describedAs(prevailing.label)
        } else if sessions.total > 0 {
            SessionCountLabel(count: sessions.total)
        }
    }
}

struct SidebarSectionTitle<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    init(_ title: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .frame(height: 28)
    }
}

struct SidebarCollapsibleTitle: View {
    let title: String
    let count: Int
    let noun: SessionCountLabel.Noun
    let isOpen: Bool
    var toggle: () -> Void

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) { toggle() }
        } label: {
            SidebarSectionTitle(title) {
                SessionCountLabel(count: count, noun: noun)
                DisclosureChevron(isOpen: isOpen)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isOpen ? "aberta" : "fechada")
    }
}

enum FavoriteTitle {
    static let add = "Favoritar"
    static let remove = "Remover dos favoritos"

    static func item(isFavorite: Bool, toggle: @escaping () -> Void) -> DenMenuItem {
        DenMenuItem(id: "favorite", title: isFavorite ? remove : add, action: toggle)
    }
}

extension View {
    func sidebarHeaderRow(hovering: Binding<Bool>, isOpen: Bool, toggle: @escaping () -> Void) -> some View {
        background(hovering.wrappedValue ? Theme.hover.opacity(0.7) : .clear,
                   in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .animation(.easeInOut(duration: 0.2), value: isOpen)
            .contentShape(Rectangle())
            .onHover { hovering.wrappedValue = $0 }
            .onTapGesture(perform: toggle)
    }
}
