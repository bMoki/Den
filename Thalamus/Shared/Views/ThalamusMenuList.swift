import SwiftUI

struct ThalamusMenuChip<Label: View>: View {
    var sections: [ThalamusMenuSection]
    var bordered = false
    var radius: Style.Radius = .r8
    var arrowEdge = Edge.top
    var opened: () -> Void = {}
    @ViewBuilder var label: () -> Label

    @State private var isOpen = false
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button { isOpen.toggle() } label: { label() }
            .buttonStyle(.plain)
            .fixedSize()
            .chipSurface(bordered: bordered, radius: radius, hovering: hovering, open: isOpen)
            .opacity(isEnabled ? 1 : 0.5)
            .onHover { hovering = isEnabled && $0 }
            .animation(.easeOut(duration: 0.12), value: hovering)
            .onChange(of: isOpen) { if isOpen { opened() } }
            .popover(isPresented: $isOpen, arrowEdge: arrowEdge) {
                ThalamusMenuList(sections: sections) { isOpen = false }
                    .presentationBackground(Theme.raised)
            }
    }
}

struct ThalamusMenuList: View {
    let sections: [ThalamusMenuSection]
    var dismiss: () -> Void = {}

    @State private var path: [ThalamusMenuItem] = []

    private static let maxHeight: CGFloat = 360

    private var shown: [ThalamusMenuSection] { path.last?.children ?? sections }

    private var showsIcons: Bool { ThalamusMenuSection.showsIcons(in: shown) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space(.s2)) {
            if let parent = path.last {
                back(to: parent)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.space(.s1)) {
                    ForEach(Array(shown.enumerated()), id: \.element.id) { index, section in
                        if index > 0, section.header == nil {
                            Rectangle()
                                .fill(Theme.border)
                                .frame(height: Theme.line(.thin))
                                .padding(.horizontal, Theme.space(.s8))
                                .padding(.vertical, Theme.space(.s4))
                        }
                        if let header = section.header {
                            Text(header)
                                .font(Theme.font(.label, weight: .semibold))
                                .foregroundStyle(Theme.textTertiary)
                                .padding(.horizontal, Theme.space(.s10))
                                .padding(.top, Theme.space(index == 0 ? .s2 : .s7))
                                .padding(.bottom, Theme.space(.s2))
                        }
                        ForEach(section.items) { item in
                            ThalamusMenuRow(item: item, showsIcon: showsIcons) { choose(item) }
                        }
                    }
                }
            }
            .frame(maxHeight: Self.maxHeight)
            .scrollBounceBehavior(.basedOnSize)
        }
        .padding(Theme.space(.s6))
        .frame(minWidth: 190, alignment: .leading)
        .accessibilityIdentifier("thalamus-menu")
        .onDisappear { path = [] }
    }

    private func back(to parent: ThalamusMenuItem) -> some View {
        BackButton(title: parent.title) {
            withAnimation(.easeOut(duration: 0.12)) { _ = path.popLast() }
        }
        .help("Voltar")
    }

    private func choose(_ item: ThalamusMenuItem) {
        guard item.children.isEmpty else {
            withAnimation(.easeOut(duration: 0.12)) { path.append(item) }
            return
        }
        item.action()
        dismiss()
    }
}

private struct ThalamusMenuRow: View {
    let item: ThalamusMenuItem
    var showsIcon: Bool
    var choose: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: choose) {
            HStack(spacing: Theme.space(.s7)) {
                if showsIcon {
                    icon.frame(width: Theme.size(.s16), height: Theme.size(.s16))
                }
                Text(item.title)
                    .font(Theme.font(.smallPlus))
                    .lineLimit(1)
                Spacer(minLength: Theme.space(.s12))
                trailing
            }
            .padding(.horizontal, Theme.space(.s10))
            .frame(height: Theme.size(.s28))
            .background(hovering ? Theme.hoverRaised : .clear,
                        in: RoundedRectangle(cornerRadius: Theme.radius(.r7), style: .continuous))
            .foregroundStyle(item.isDestructive ? Theme.removed
                             : item.isSelected ? Theme.text : Theme.textSecondary)
            .opacity(item.isEnabled ? 1 : 0.45)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!item.isEnabled)
        .onHover { hovering = item.isEnabled && $0 }
    }

    @ViewBuilder
    private var icon: some View {
        switch item.icon {
        case .symbol(let name, let color):
            Theme.image(name)
                .font(Theme.font(.caption, weight: .medium))
                .foregroundStyle(color)
        case .image(let image):
            image.resizable().frame(width: Theme.size(.s16), height: Theme.size(.s16))
        case nil:
            Color.clear
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if !item.children.isEmpty {
            Theme.image(.next)
                .font(Theme.font(.mini, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
        } else if item.isSelected {
            Theme.image(.done)
                .font(Theme.font(.label, weight: .semibold))
                .foregroundStyle(Theme.accent)
        } else if let shortcut = item.shortcut {
            Text(shortcut)
                .font(Theme.font(.caption, design: .monospaced))
                .foregroundStyle(Theme.textTertiary)
        }
    }
}
