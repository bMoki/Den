import HarnessCore
import SwiftUI

struct NewSessionRow: View {
    let workspace: WorkspaceModel
    var directory: URL?

    var body: some View {
        Button {
            Task { await workspace.newSession(in: directory) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(width: 18)
                Text("Nova sessão")
                    .font(.system(size: 13, weight: .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 10)
            .frame(height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.thalamusGhost)
        .thalamusContextMenu([ThalamusMenuSection(items: workspace.availableHarnesses.map { harness in
            ThalamusMenuItem(id: harness.rawValue,
                        title: "Nova sessão com \(HarnessBadge.name(for: harness))",
                        icon: .image(HarnessBadge.menuIcon(for: harness))) {
                Task { await workspace.newSession(in: directory, harness: harness) }
            }
        })])
        .help("Iniciar uma sessão nova")
    }
}

struct SidebarEmptyList: View {
    let search: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: search.isEmpty ? "bubble.left.and.bubble.right"
                                                      : "magnifyingglass")
                .font(.system(size: 20))
                .foregroundStyle(Theme.textFaint)
            Text(search.isEmpty ? "Nenhuma conversa"
                                          : "Nada encontrado para \"\(search)\"")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}
