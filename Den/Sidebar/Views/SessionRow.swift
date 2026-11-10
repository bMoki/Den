import SwiftUI
import HarnessCore

struct SessionRow: View {
    let summary: SessionSummary
    let state: SessionState?
    var isSelected = false
    var showsActivity = false
    var isReadOnly = false
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

            if showsActivity {
                Text(summary.updatedAt.formatted(.relative(presentation: .named).locale(Locale(identifier: "pt_BR"))))
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }

            if let state {
                SessionStateDot(state: state)
                    .describedAs(state.name)
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
            guard !isReadOnly else { return }
            Task { @MainActor in isEditing = true }
        })
        .thalamusContextMenu(menuSections)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var menuSections: [ThalamusMenuSection] {
        let rename = ThalamusMenuSection(id: "edit", items: [
            ThalamusMenuItem(id: "rename", title: "Renomear") { isEditing = true },
        ])
        return (isReadOnly ? [] : [rename]) + [
            ThalamusMenuSection(id: "danger", items: [
                ThalamusMenuItem(id: "delete", title: "Apagar sessão…",
                            isDestructive: true, action: delete),
            ]),
        ]
    }
}
