import SwiftUI

struct InspectorView: View {
    @Binding var pane: InspectorPane
    let gitChanges: GitChangesModel
    let files: FileTree
    let directory: URL
    let branch: String?
    let removedBranch: String?
    var open: (URL) -> Void
    var mention: ((_ path: String, _ isDirectory: Bool) -> Void)?

    var body: some View {
        let shown = pane.shown(inBranch: branch != nil)
        VStack(spacing: 0) {
            TopBar(leadingInset: Theme.space(.s12)) {
                HStack(spacing: Theme.space(.s2)) {
                    if branch != nil {
                        tab(.services, title: "Serviços", symbol: .services, shown: shown)
                    }
                    tab(.files, title: "Arquivos", symbol: .folder, shown: shown)
                        tab(.changes, title: "Alterações", symbol: .diff, shown: shown) {
                            if gitChanges.changeCount > 0 {
                                Text("\(gitChanges.changeCount)")
                                    .font(Theme.font(.caption, weight: .medium))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.textSecondary)
                                    .padding(.horizontal, Theme.space(.s6))
                                    .padding(.vertical, Theme.space(.s1))
                                    .background(Theme.hoverRaised, in: Capsule())
                            }
                        }
                }
                Spacer(minLength: Theme.space(.s4))
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { pane = .closed }
                } label: {
                    Theme.image(.close)
                        .font(Theme.font(.small, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .iconLabel()
                }
                .buttonStyle(.thalamusGhost)
                .tip("Recolher painel", shortcut: "⌥⌘0")
                .accessibilityLabel("Fechar painel")
            }

            Group {
                if shown == .services, let branch {
                    ServicesPanel(branch: branch, directory: directory)
                } else if shown == .files {
                    FilesPanel(tree: files, directory: directory, removedBranch: removedBranch, open: open, mention: mention)
                } else {
                    GitChangesPanel(model: gitChanges, directory: directory)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.panel)
        .task(id: "\(shown == .changes)|\(directory.path)") {
            guard shown == .changes else { return }
            await gitChanges.load(directory: directory)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                guard !Task.isCancelled else { return }
                await gitChanges.load(directory: directory)
            }
        }
    }

    private func tab(_ target: InspectorPane, title: String, symbol: Icon, shown: InspectorPane,
                     @ViewBuilder trailing: () -> some View = { EmptyView() }) -> some View {
        let isOn = shown == target
        return Button {
            pane = target
        } label: {
            HStack(spacing: Theme.space(.s7)) {
                Theme.image(symbol)
                    .font(Theme.font(.small, weight: .medium))
                Text(title)
                    .font(Theme.font(.body, weight: .medium))
                trailing()
            }
            .foregroundStyle(isOn ? Theme.text : Theme.textTertiary)
            .padding(.horizontal, Theme.space(.s12))
            .frame(height: Theme.size(.s32))
            .background(isOn ? Theme.hoverRaised : .clear,
                        in: RoundedRectangle(cornerRadius: Theme.radius(.r8), style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
