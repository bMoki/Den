import HarnessCore
import SwiftUI

struct NewSessionRow: View {
    let workspace: WorkspaceModel
    var directory: URL?

    var body: some View {
        Button {
            Task { await workspace.newSession(in: directory) }
        } label: {
            HStack(spacing: Theme.space(.s8)) {
                Theme.image(.add, size: .body, weight: .semibold)
                    .frame(width: Theme.size(.s18))
                Text("Nova sessão")
                    .font(Theme.font(.body, weight: .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, Theme.space(.s10))
            .frame(height: Theme.size(.s32))
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
        .tip("Iniciar uma sessão nova")
    }
}

struct SidebarEmptyList: View {
    let search: String

    var body: some View {
        VStack(spacing: Theme.space(.s6)) {
            Theme.image(search.isEmpty ? .noSessions : .search, size: .title2)
                .foregroundStyle(Theme.textFaint)
            Text(search.isEmpty ? "Nenhuma conversa"
                                          : "Nada encontrado para \"\(search)\"")
                .font(Theme.font(.small, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.space(.s28))
    }
}
