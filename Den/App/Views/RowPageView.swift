import SwiftUI
import HarnessCore

struct RowPageView: View {
    let row: SidebarRow
    let workspace: WorkspaceModel
    let gitChanges: GitChangesModel
    let files: FileTree
    let editors: EditorTabs

    @Environment(NsWorkspace.self) private var ns
    @Environment(\.chrome) private var chrome
    @AppStorage(InspectorPane.storageKey) private var pane: InspectorPane = .closed
    @State private var pendingDelete: SessionSummary?

    var body: some View {
        let groups = workspace.groups(in: ns, search: workspace.search)
        let sessions = row == .archived ? groups.archived : groups.folder(row)?.sessions ?? []
        InspectorSplit(isShown: root != nil && pane != .closed) {
            VStack(spacing: 0) {
                header
                if let root {
                    EditorTabStrip(tabs: editors, row: row, files: files, home: .page)
                    if let document = editors.selection(in: row) {
                        EditorView(document: document, folder: root) { editors.close(document, in: row) }
                    } else {
                        list(sessions: sessions)
                    }
                    TerminalPanel(row: row, root: root)
                } else {
                    list(sessions: sessions)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.canvas)
        } inspector: {
            if let root {
                InspectorView(pane: $pane, gitChanges: gitChanges, files: files,
                              directory: root, branch: branch, removedBranch: nil,
                              open: { editors.open($0, in: row) }, mention: nil)
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
            Button("Apagar", role: .destructive, action: delete)
            Button("Cancelar", role: .cancel) { pendingDelete = nil }
        } message: {
            Text("A conversa e o histórico dela serão removidos permanentemente.")
        }
    }

    private var root: URL? {
        row == .archived ? nil : ns.root(of: row)
    }

    private func list(sessions: [SessionSummary]) -> some View {
        ScrollView {
            content(sessions: sessions)
                .frame(maxWidth: 720, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.never)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("RowPage")
    }

    private var branchStatus: NsStatus.Branch? {
        row.branch.flatMap(ns.branch(named:))
    }

    private var branch: String? {
        branchStatus?.branch
    }

    private var header: some View {
        TopBar(leadingInset: chrome.headerInset) {
            SidebarToggle()
            Text(ns.title(of: row))
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 12)
            if let root {
                TerminalToggle(row: row, root: root)
                InspectorToggle(isOpen: pane != .closed, action: toggleInspector)
            }
        }
        .onKeyboardShortcut("0", modifiers: [.option, .command]) { if root != nil { toggleInspector() } }
    }

    private func toggleInspector() {
        withAnimation(.easeInOut(duration: 0.2)) { pane = pane == .closed ? .opening(inBranch: branch != nil) : .closed }
    }

    private func content(sessions: [SessionSummary]) -> some View {
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
            if let root {
                NewSessionRow(workspace: workspace, directory: root)
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

    private func delete() {
        guard let summary = pendingDelete else { return }
        pendingDelete = nil
        Task { await workspace.deleteSession(summary.id) }
    }
}
