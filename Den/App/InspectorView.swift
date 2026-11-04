import SwiftUI

struct InspectorView: View {
    @Binding var pane: InspectorPane
    let gitChanges: GitChangesModel
    let directory: URL

    var body: some View {
        VStack(spacing: 0) {
            TopBar(leadingInset: 12) {
                HStack(spacing: 7) {
                    Image(systemName: "plus.forwardslash.minus")
                        .font(.system(size: 12, weight: .medium))
                    Text("Alterações")
                        .font(.system(size: 13, weight: .medium))
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
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 12)
                .frame(height: 32)
                Spacer(minLength: 4)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { pane = .closed }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                        .iconLabel()
                }
                .buttonStyle(.denGhost)
                .help("Recolher painel (⌥⌘0)")
                .accessibilityLabel("Fechar painel")
            }

            GitChangesPanel(model: gitChanges, directory: directory)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.panel)
    }
}
