import SwiftUI

struct SlashCommandList: View {
    let commands: [SlashCommand]
    let selection: Int
    let group: SlashGroup?
    var choose: (SlashCommand) -> Void
    var back: () -> Void

    private static var rowHeight: CGFloat { Theme.size(.s28) }
    private static var rowSpacing: CGFloat { Theme.space(.s1) }
    private static let visibleRows = 8

    private var listHeight: CGFloat {
        let rows = CGFloat(min(commands.count, Self.visibleRows))
        return rows * Self.rowHeight + max(rows - 1, 0) * Self.rowSpacing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space(.s1)) {
            if let group {
                BackButton(title: group.title, back: back)
                    .tip("Voltar", shortcut: "esc")
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: Self.rowSpacing) {
                        rows
                    }
                }
                .frame(height: listHeight)
                .scrollBounceBehavior(.basedOnSize)
                .onChange(of: selection) { _, index in
                    guard commands.indices.contains(index) else { return }
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(commands[index].id, anchor: .center)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rows: some View {
        ForEach(Array(commands.enumerated()), id: \.element.id) { index, command in
            let isSelected = index == selection
            HStack(spacing: Theme.space(.s7)) {
                Theme.image(command.icon)
                    .font(Theme.font(.caption))
                    .frame(width: Theme.size(.s16))
                    .foregroundStyle(isSelected ? AnyShapeStyle(Theme.accent)
                                                : AnyShapeStyle(command.tint))
                Text(command.title)
                    .font(Theme.font(.smallPlus, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                Text(command.detail)
                    .font(Theme.font(.small))
                    .foregroundStyle(isSelected ? Theme.textSecondary : Theme.textTertiary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                if command.group != nil {
                    Theme.image(.next)
                        .font(Theme.font(.mini, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(.horizontal, Theme.space(.s10))
            .frame(height: Self.rowHeight)
            .background(isSelected ? Theme.hoverRaised : .clear,
                        in: RoundedRectangle(cornerRadius: Theme.radius(.r7), style: .continuous))
            .foregroundStyle(isSelected ? Theme.text : Theme.textSecondary)
            .contentShape(Rectangle())
            .onTapGesture { choose(command) }
            .id(command.id)
        }
    }
}
