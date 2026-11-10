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
            TopBar(leadingInset: 12) {
                HStack(spacing: 2) {
                    if branch != nil {
                        tab(.services, title: "Serviços", symbol: "server.rack", shown: shown)
                    }
                    tab(.files, title: "Arquivos", symbol: "folder", shown: shown)
                        tab(.changes, title: "Alterações", symbol: "plus.forwardslash.minus", shown: shown) {
                            if gitChanges.changeCount > 0 {
                                Text("\(gitChanges.changeCount)")
                                    .font(.system(size: 11, weight: .medium))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.textSecondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Theme.hoverRaised, in: Capsule())
                            }
                        }
                }
                Spacer(minLength: 4)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { pane = .closed }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .iconLabel()
                }
                .buttonStyle(.thalamusGhost)
                .help("Recolher painel (⌥⌘0)")
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

    private func tab(_ target: InspectorPane, title: String, symbol: String, shown: InspectorPane,
                     @ViewBuilder trailing: () -> some View = { EmptyView() }) -> some View {
        let isOn = shown == target
        return Button {
            pane = target
        } label: {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                trailing()
            }
            .foregroundStyle(isOn ? Theme.text : Theme.textTertiary)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(isOn ? Theme.hoverRaised : .clear,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
