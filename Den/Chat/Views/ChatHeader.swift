import SwiftUI

struct ChatHeader: View {
    let chat: ChatModel
    var openPage: (SidebarRow) -> Void

    @AppStorage(InspectorPane.storageKey) private var pane: InspectorPane = .closed
    @Environment(\.chrome) private var chrome
    @Environment(NsWorkspace.self) private var ns

    var body: some View {
        TopBar(leadingInset: chrome.headerInset) {
            SidebarToggle()
            ViewThatFits(in: .horizontal) {
                breadcrumb(branch: true)
                breadcrumb(branch: false)
            }
            Spacer(minLength: 12)
            HarnessSwitcher(chat: chat)
            TerminalToggle(row: ns.row(of: chat.workingDirectory), root: ns.rowRoot(of: chat.workingDirectory))
            InspectorToggle(isOpen: pane != .closed, action: toggle)
        }
        .onKeyboardShortcut("0", modifiers: [.option, .command]) { toggle() }
    }

    private var removedBranch: String? { ns.removedBranch(of: chat.workingDirectory) }

    private func breadcrumb(branch: Bool) -> some View {
        HStack(spacing: 8) {
            let place = ns.row(of: chat.workingDirectory)
            let title = ns.title(of: place)
            Button { openPage(place) } label: {
                Text(title)
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .buttonStyle(.plain)
            .layoutPriority(-1)
            .help("Abrir a página de \(title)")
            Text("›")
                .foregroundStyle(Theme.textFaint)
            Text(chat.title)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.tail)
            if branch, let removedBranch {
                BranchPill(branch: removedBranch, isRemoved: true)
            } else if branch, let name = chat.branch {
                BranchPill(branch: name)
            }
        }
        .font(.system(size: 14))
    }

    private func toggle() {
        withAnimation(.easeInOut(duration: 0.2)) {
            pane = pane == .closed ? .opening(inBranch: ns.branchName(of: chat.workingDirectory) != nil) : .closed
        }
    }
}

struct InspectorToggle: View {
    let isOpen: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 14))
                .foregroundStyle(isOpen ? Theme.text : Theme.textSecondary)
                .iconLabel(size: 32)
        }
        .buttonStyle(DenButtonStyle(kind: .secondary))
        .help(isOpen ? "Ocultar painel" : "Mostrar painel (⌥⌘0)")
        .accessibilityLabel(isOpen ? "Ocultar painel" : "Mostrar painel")
    }
}

struct BranchPill: View {
    let branch: String
    var isRemoved = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 10, weight: .semibold))
            Text(branch)
                .strikethrough(isRemoved)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.system(size: 11.5, design: .monospaced))
        .foregroundStyle(isRemoved ? Theme.textTertiary : Theme.textSecondary)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .frame(minWidth: isRemoved ? 96 : nil, maxWidth: 220)
        .background(Theme.field, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .fixedSize(horizontal: !isRemoved, vertical: true)
        .help(isRemoved ? "Branch de workspace removida" : branch)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isRemoved ? "Branch \(branch), removida" : branch)
    }
}
