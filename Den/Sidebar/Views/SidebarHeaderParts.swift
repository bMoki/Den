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
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.system(size: 11))
            .monospacedDigit()
            .foregroundStyle(Theme.textTertiary)
            .accessibilityLabel(count == 1 ? "1 sessão" : "\(count) sessões")
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
