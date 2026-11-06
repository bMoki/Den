import SwiftUI
import HarnessCore

struct SessionRow: View {
    let summary: SessionSummary
    let state: SessionState?
    var isSelected = false
    var select: () -> Void
    var rename: (String) -> Void
    var delete: () -> Void = {}

    @State private var isEditing = false
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            HarnessBadge(harness: summary.harnesses.last, size: 18)

            if isEditing {
                InlineRenameField(initial: summary.title, commit: rename) {
                    isEditing = false
                }
                .font(.system(size: 13))
            } else {
                Text(summary.title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? Theme.text : Theme.text.opacity(0.88))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 4)

            if let state {
                SessionStateDot(state: state)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 32)
        .hoverFill(hovering, selected: isSelected)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .simultaneousGesture(TapGesture().onEnded {
            guard !isEditing else { return }
            select()
        })
        .simultaneousGesture(TapGesture(count: 2).onEnded {
            Task { @MainActor in isEditing = true }
        })
        .denContextMenu(menuSections)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var menuSections: [DenMenuSection] {
        [
            DenMenuSection(id: "edit", items: [
                DenMenuItem(id: "rename", title: "Renomear") { isEditing = true },
            ]),
            DenMenuSection(id: "danger", items: [
                DenMenuItem(id: "delete", title: "Apagar sessão…",
                            isDestructive: true, action: delete),
            ]),
        ]
    }
}
