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
        HStack(spacing: 8) {
            Image(systemName: sessions.total > 0 ? "folder.fill" : "folder")
                .font(.system(size: 13))
                .foregroundStyle(sessions.total > 0 ? Theme.accent : Theme.textTertiary)
                .frame(width: 16)
            Text(name)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 4)
            if let detail {
                Text(detail)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            SessionTallyLabel(sessions: sessions)
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .sidebarHeaderRow(hovering: $hovering, isSelected: isSelected, open: open)
        .denContextMenu([
            DenMenuSection(id: "new", items: [
                DenMenuItem(id: "new-session", title: "Nova sessão aqui", action: newSession),
                FavoriteTitle.item(isFavorite: isFavorite, toggle: toggleFavorite),
            ]),
        ])
        .accessibilityElement(children: .combine)
        .accessibilityLabel(name)
        .accessibilityAddTraits(.isButton)
    }
}
