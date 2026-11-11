import SwiftUI

struct FolderHeader: View {
    let name: String
    var detail: String?
    let sessions: SessionTally
    let isSelected: Bool
    var open: () -> Void
    var newSession: () -> Void
    let isFavorite: Bool
    var toggleFavorite: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: Theme.space(.s8)) {
            Theme.image(sessions.total > 0 ? .folderWithSessions : .folder)
                .font(Theme.font(.body))
                .foregroundStyle(sessions.total > 0 ? Theme.accent : Theme.textTertiary)
                .frame(width: Theme.size(.s16))
            Text(name)
                .font(Theme.font(.body, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: Theme.space(.s4))
            if let detail {
                Text(detail)
                    .font(Theme.font(.caption, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            SessionTallyLabel(sessions: sessions)
        }
        .padding(.horizontal, Theme.space(.s10))
        .frame(height: Theme.size(.s32))
        .sidebarHeaderRow(hovering: $hovering, isSelected: isSelected, open: open)
        .thalamusContextMenu([
            ThalamusMenuSection(id: "new", items: [
                ThalamusMenuItem(id: "new-session", title: "Nova sessão aqui", action: newSession),
                FavoriteTitle.item(isFavorite: isFavorite, toggle: toggleFavorite),
            ]),
        ])
        .accessibilityElement(children: .combine)
        .accessibilityLabel(name)
        .accessibilityAddTraits(.isButton)
    }
}
