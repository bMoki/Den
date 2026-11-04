import SwiftUI

struct FolderHeader: View {
    enum Kind {
        case branch, folder
    }

    let kind: Kind
    let name: String
    var detail: String?
    let sessionCount: Int
    let isOpen: Bool
    var toggle: () -> Void
    var newSession: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .rotationEffect(.degrees(isOpen ? 90 : 0))
                .frame(width: 12)
                .opacity(sessionCount == 0 && kind == .folder ? 0 : 1)
            if kind == .folder {
                Image(systemName: sessionCount > 0 ? "folder.fill" : "folder")
                    .font(.system(size: 13))
                    .foregroundStyle(sessionCount > 0 ? Theme.accent : Theme.textTertiary)
                    .frame(width: 16)
            }
            Text(name)
                .font(kind == .branch ? .system(size: 12.5, weight: .medium, design: .monospaced)
                                      : .system(size: 13, weight: .medium))
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
            if sessionCount > 0 {
                Text("\(sessionCount)")
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textTertiary)
                    .accessibilityLabel(sessionCount == 1 ? "1 sessão" : "\(sessionCount) sessões")
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(hovering ? Theme.hover.opacity(0.7) : .clear,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .animation(.easeInOut(duration: 0.2), value: isOpen)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: toggle)
        .denContextMenu([
            DenMenuSection(id: "new", items: [
                DenMenuItem(id: "new-session", title: "Nova sessão aqui", action: newSession),
            ]),
        ])
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(isOpen ? "aberta" : "fechada")
    }
}
