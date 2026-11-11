import HarnessCore
import SwiftUI

struct SidebarHeader: View {
    let workspace: WorkspaceModel
    var lightsInset: CGFloat
    var collapse: () -> Void

    private var newSections: [ThalamusMenuSection] {
        let harnesses = workspace.availableHarnesses.map { harness in
            ThalamusMenuItem(id: harness.rawValue,
                        title: HarnessBadge.name(for: harness),
                        icon: .image(HarnessBadge.menuIcon(for: harness))) {
                Task { await workspace.newSession(harness: harness) }
            }
        }
        return [ThalamusMenuSection(items: [
            ThalamusMenuItem(id: "new-session", title: "Nova sessão") {
                Task { await workspace.newSession() }
            },
            ThalamusMenuItem(id: "new-session-with", title: "Nova sessão com",
                        children: [ThalamusMenuSection(items: harnesses)]),
            ThalamusMenuItem(id: "open-folder", title: "Abrir pasta…") {
                workspace.openFolder()
            },
        ])]
    }

    var body: some View {
        HStack(spacing: Theme.space(.s8)) {
            Spacer(minLength: Theme.space(.s4))
            ThalamusMenuChip(sections: newSections) {
                Theme.image(.newSession)
                    .font(Theme.font(.large))
                    .foregroundStyle(Theme.textMuted)
                    .iconLabel()
            }
            .tip("Nova sessão")
            .accessibilityLabel("Nova")
            SidebarButton(title: "Recolher barra lateral", action: collapse)
        }
        .padding(.leading, lightsInset + Theme.space(.s6))
        .padding(.trailing, Theme.space(.s10))
        .frame(height: Theme.headerHeight)
        .windowDragArea()
    }
}

extension WorkspaceModel {
    func openFolder() {
        guard let folder = FolderPicker.choose(prompt: "Abrir", from: workingDirectory) else { return }
        Task { await newSession(in: folder) }
    }
}

struct SidebarSearch: View {
    @Bindable var workspace: WorkspaceModel

    @FocusState private var searchFocused: Bool

    var body: some View {
        HStack(spacing: Theme.space(.s8)) {
            Theme.image(.search)
                .font(Theme.font(.small, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
            TextField("Buscar sessões…", text: $workspace.search)
                .textFieldStyle(.plain)
                .font(Theme.font(.body))
                .focused($searchFocused)
                .onExitCommand {
                    workspace.search = ""
                    searchFocused = false
                }
            if !workspace.search.isEmpty {
                Button {
                    workspace.search = ""
                } label: {
                    Theme.image(.clearSearch)
                        .font(Theme.font(.small))
                        .foregroundStyle(Theme.textTertiary)
                }
                .buttonStyle(.plain)
                .tip("Limpar busca")
                .accessibilityLabel("Limpar busca")
            }
        }
        .padding(.horizontal, Theme.space(.s12))
        .frame(height: Theme.size(.s34))
        .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.radius(.r10), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius(.r10), style: .continuous)
            .strokeBorder(searchFocused ? Theme.accent.opacity(0.55) : .clear, lineWidth: Theme.line(.thin)))
        .padding(.horizontal, Theme.space(.s12))
        .padding(.bottom, Theme.space(.s10))
        .onKeyboardShortcut("f", modifiers: [.command, .shift]) { searchFocused = true }
    }
}
