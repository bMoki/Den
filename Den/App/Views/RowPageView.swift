import SwiftUI
import HarnessCore

struct RowPageView: View {
    let row: SidebarRow
    let workspace: WorkspaceModel
    let gitChanges: GitChangesModel
    let files: FileTree

    @Environment(NsWorkspace.self) private var ns
    @Environment(PanelTerminals.self) private var terminals
    @Environment(\.chrome) private var chrome
    @AppStorage(InspectorPane.storageKey) private var pane: InspectorPane = .closed
    @State private var pendingDelete: SessionSummary?
    private let editors = EditorWindows.shared

    var body: some View {
        let groups = workspace.groups(in: ns, search: workspace.search)
        let sessions = row == .archived ? groups.archived : groups.folder(row)?.sessions ?? []
        InspectorSplit(isShown: branch != nil && pane != .closed) {
            VStack(spacing: 0) {
                header
                ScrollView {
                    content(sessions: sessions, directory: directory(in: groups))
                        .frame(maxWidth: 720, alignment: .leading)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.never)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("RowPage")
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.canvas)
        } inspector: {
            if let branch, let directory = directory(in: groups) {
                InspectorView(pane: $pane, gitChanges: gitChanges, files: files, sessionID: nil,
                              directory: directory, branch: branch, removedBranch: nil,
                              open: { _ in }, mention: { _, _ in })
            }
        }
        .navigationTitle(ns.title(of: row))
        .confirmationDialog(
            "Apagar \"\(pendingDelete?.title ?? "")\"?",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            if pendingUnsaved.isEmpty {
                Button("Apagar", role: .destructive) { delete(.discard) }
            } else {
                Button("Salvar e apagar") { delete(.saveAll) }
                Button("Apagar sem salvar", role: .destructive) { delete(.discard) }
            }
            Button("Cancelar", role: .cancel) { pendingDelete = nil }
        } message: {
            let unsaved = pendingUnsaved.isEmpty ? "" : " \(UnsavedAlert.listing(pendingUnsaved))"
            Text("A conversa e o histórico dela serão removidos permanentemente.\(unsaved)")
        }
    }

    private var branchStatus: NsStatus.Branch? {
        row.branch.flatMap(ns.branch(named:))
    }

    private var branch: String? {
        branchStatus?.branch
    }

    private func directory(in groups: SidebarGroups) -> URL? {
        switch row {
        case .branch: branchStatus.map { URL(fileURLWithPath: $0.path) }
        case .baseRepo: groups.folder(row)?.path
        case .folder(let path): URL(fileURLWithPath: path)
        case .archived: nil
        }
    }

    private var header: some View {
        TopBar(leadingInset: chrome.headerInset) {
            SidebarToggle()
            Text(ns.title(of: row))
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 12)
            if branch != nil {
                InspectorToggle(isOpen: pane != .closed) {
                    withAnimation(.easeInOut(duration: 0.2)) { pane = pane == .closed ? .opening(inBranch: true) : .closed }
                }
            }
        }
    }

    private func content(sessions: [SessionSummary], directory: URL?) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                title
                Text(subtitle(count: sessions.count))
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textTertiary)
            }
            if !sessions.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(sessions) { summary in
                        SessionRow(summary: summary, state: workspace.state(for: summary.id), showsActivity: true,
                                   isReadOnly: row == .archived,
                                   select: { Task { await workspace.select(summary.id) } },
                                   rename: { name in Task { await workspace.renameSession(summary.id, to: name) } },
                                   delete: { pendingDelete = summary })
                    }
                }
            }
            if row != .archived, let directory {
                NewSessionRow(workspace: workspace, directory: directory)
                    .frame(maxWidth: 220, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var title: some View {
        let nickname = branchStatus?.nickname
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(ns.title(of: row))
                .font(.system(size: 20, weight: .semibold, design: nickname == nil && row.branch != nil ? .monospaced : .default))
                .lineLimit(1)
            if nickname != nil, let name = row.branch {
                Text(name)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
        }
    }

    private func subtitle(count: Int) -> String {
        let sessions = count == 1 ? "1 sessão" : "\(count) sessões"
        if row == .archived { return "\(sessions) de branches removidas, só para leitura" }
        return count == 0 ? "Nenhuma sessão ainda" : sessions
    }

    private var pendingUnsaved: [EditorDocument] {
        pendingDelete.map { editors.unsaved(in: $0.id) } ?? []
    }

    private func delete(_ choice: UnsavedChoice) {
        guard let summary = pendingDelete else { return }
        pendingDelete = nil
        let unsaved = editors.unsaved(in: summary.id)
        guard editors.settle(choice, in: summary.id) else {
            UnsavedAlert.tellFailure(unsaved.filter(\.isDirty))
            Task { await workspace.select(summary.id) }
            return
        }
        editors.closeSession(summary.id)
        terminals.close(sessionID: summary.id)
        Task { await workspace.deleteSession(summary.id) }
    }
}
