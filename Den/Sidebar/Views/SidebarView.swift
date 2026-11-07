import SwiftUI
import HarnessCore

struct SidebarView: View {
    @Bindable var workspace: WorkspaceModel
    @Environment(PullRequestMonitor.self) private var monitor
    @Environment(NsWorkspace.self) private var ns
    @Environment(PanelTerminals.self) private var terminals
    private let editors = EditorWindows.shared
    var lightsInset: CGFloat = 0
    var collapse: () -> Void = {}

    @State private var toggled: Set<String> = []
    @State private var archivedOpen = false
    @State private var favoritesOpen = true
    @State private var pendingDelete: SessionSummary?

    @State private var tipTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            SidebarHeader(workspace: workspace, lightsInset: lightsInset, collapse: collapse)
            SidebarSearch(workspace: workspace)
            list
        }
        .background(Theme.sidebar)
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
        .sheet(isPresented: Binding(
            get: { ns.creation?.isPresented == true },
            set: { if !$0 { ns.creation?.isPresented = false } }
        )) {
            if let creation = ns.creation {
                NewBranchSheet(creation: creation) { create(with: creation) }
            }
        }
        .sheet(item: Binding(get: { ns.removal }, set: { if $0 == nil { ns.cancelRemoval() } })) { removal in
            RemoveBranchSheet(removal: removal, cancel: ns.cancelRemoval) { purge in
                Task { await ns.remove(removal.branch, purge: purge) }
            }
        }
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

    private func create(with creation: BranchCreation) {
        Task {
            await creation.create { root in
                await workspace.newSession(in: root, harness: HarnessRegistry.branchSessionHarness)
            }
        }
    }

    // MARK: - List

    private var groups: SidebarGroups {
        SidebarGroups(sessions: workspace.summaries, status: ns.status, search: workspace.search,
                      layout: workspace.layout, place: ns.place(of:))
    }

    private var list: some View {
        let groups = groups
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                if let problem = ns.problem {
                    NsProblemNotice(problem: problem, keepsLastBranches: ns.status != nil)
                }

                if !groups.favorites.isEmpty {
                    favorites(groups.favorites)
                }

                if ns.status != nil {
                    SidebarSectionTitle("Branches de workspace") {
                        SidebarOrderMenu(layout: $workspace.layout)
                        Button(action: ns.newBranch) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .semibold))
                                Text("Branch")
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(Theme.textMuted)
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                        }
                        .buttonStyle(.denGhost(radius: 6))
                        .help("Nova Branch de workspace")
                        .accessibilityLabel("Nova Branch de workspace")
                    }
                    .padding(.top, groups.favorites.isEmpty ? 0 : 14)
                    ForEach(groups.branches) { folder($0) }
                }

                if !groups.baseRepos.isEmpty {
                    SidebarSectionTitle("Repos base") { EmptyView() }
                        .padding(.top, 14)
                    ForEach(groups.baseRepos) { folder($0) }
                }

                SidebarSectionTitle("Outras pastas") {
                    Button(action: workspace.openFolder) {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                            .iconLabel(size: 22)
                    }
                    .buttonStyle(.denGhost(radius: 6))
                    .help("Abrir pasta")
                    .accessibilityLabel("Abrir pasta")
                }
                .padding(.top, ns.status == nil && groups.favorites.isEmpty ? 0 : 14)
                ForEach(groups.otherFolders) { folder($0) }

                if !groups.archived.isEmpty {
                    archived(groups.archived)
                }

                if groups.isEmpty {
                    SidebarEmptyList(search: workspace.search)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
        .scrollIndicators(.never)
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Sidebar")
        .onChange(of: ns.status, initial: true) {
            if let status = ns.status { workspace.layout = workspace.layout.pruned(by: status) }
        }
        .onChange(of: workspace.summaries, initial: true) {
            monitor.noteActivity(Dictionary(workspace.summaries.compactMap { summary in
                ns.branchName(of: summary.workingDirectory).map { ($0, summary.updatedAt) }
            }, uniquingKeysWith: { max($0, $1) }))
        }
    }

    @ViewBuilder
    private func favorites(_ folders: [SidebarGroups.Folder]) -> some View {
        let isOpen = favoritesOpen || !workspace.search.isEmpty
        SidebarCollapsibleTitle(title: "Favoritos", count: folders.count, noun: .favorites, isOpen: isOpen) {
            favoritesOpen.toggle()
        }
        if isOpen {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(folders) { folder($0) }
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private func archived(_ sessions: [SessionSummary]) -> some View {
        let isOpen = archivedOpen || !workspace.search.isEmpty
        SidebarCollapsibleTitle(title: "Arquivadas", count: sessions.count, noun: .sessions, isOpen: isOpen) {
            archivedOpen.toggle()
        }
            .padding(.top, 14)
        if isOpen {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(sessions) { row(for: $0) }
            }
            .transition(.opacity)
        }
    }

    private func isOpen(_ folder: SidebarGroups.Folder) -> Bool {
        let opensByDefault = !folder.sessions.isEmpty
        let flipped = toggled.contains(folder.id)
        return !workspace.search.isEmpty || (flipped ? !opensByDefault : opensByDefault)
    }

    @ViewBuilder
    private func folder(_ folder: SidebarGroups.Folder) -> some View {
        let isOpen = isOpen(folder)
        let isBranch = folder.kind == .branch
        let isFavorite = workspace.layout.isFavorite(folder.favorite)
        let toggleFavorite = { workspace.layout.toggle(folder.favorite) }
        Group {
            if isBranch {
                BranchHeader(
                    name: folder.name,
                    branch: ns.branch(named: folder.name),
                    activity: ns.activity[folder.name],
                    problem: ns.actionProblems[folder.name],
                    pullRequests: monitor.pullRequests(for: folder.name).map(\.pullRequest),
                    sessions: workspace.tally(folder.sessions),
                    isOpen: isOpen,
                    toggle: { toggle(folder) },
                    newSession: { Task { await workspace.newSession(in: folder.path) } },
                    start: { Task { await ns.start(folder.name) } },
                    stop: { Task { await ns.stop(folder.name) } },
                    update: { Task { await ns.update(folder.name) } },
                    remove: { Task { await ns.askToRemove(folder.name) } },
                    setNickname: { text in Task { await ns.setNickname(folder.name, to: text) } },
                    isFavorite: isFavorite,
                    toggleFavorite: toggleFavorite
                )
            } else {
                FolderHeader(
                    name: folder.name,
                    detail: folder.kind == .folder ? Self.parent(of: folder.path) : nil,
                    sessions: workspace.tally(folder.sessions),
                    isOpen: isOpen,
                    toggle: { toggle(folder) },
                    newSession: { Task { await workspace.newSession(in: folder.path) } },
                    isFavorite: isFavorite,
                    toggleFavorite: toggleFavorite
                )
            }
        }
        .hoverTip({ anchor in
            PaneTip(title: folder.nickname ?? folder.name,
                    caption: folder.nickname.map { _ in folder.name },
                    detail: tipDetail(for: folder, isBranch: isBranch),
                    state: nil, anchor: anchor,
                    lines: isBranch ? PaneTip.Line.pullRequests(monitor.pullRequests(for: folder.name)) : [])
        }, update: { scheduleTip($0) })

        if isOpen, isBranch || !folder.sessions.isEmpty {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(folder.sessions) { row(for: $0) }
                if isBranch {
                    NewSessionRow(workspace: workspace, directory: folder.path)
                }
            }
            .padding(.leading, 22)
            .padding(.bottom, 4)
            .transition(.opacity)
        }
    }

    private func tipDetail(for folder: SidebarGroups.Folder, isBranch: Bool) -> String {
        let path = (folder.path.path as NSString).abbreviatingWithTildeInPath
        guard isBranch else { return path }
        guard let branch = ns.branch(named: folder.name), !branch.services.isEmpty else { return path }
        return "\(path)\n\(branch.stateSummary)"
    }

    private static func parent(of path: URL) -> String {
        (path.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath
    }

    private func scheduleTip(_ next: PaneTip?) {
        tipTask?.cancel()
        guard let next else {
            HoverTipPanel.shared.hide()
            return
        }
        let delay = HoverTipPanel.shared.isVisible ? 60 : 350
        tipTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(delay))
            guard !Task.isCancelled else { return }
            HoverTipPanel.shared.show(next)
        }
    }

    private func row(for summary: SessionSummary) -> some View {
        SessionRow(
            summary: summary,
            state: workspace.state(for: summary.id),
            isSelected: workspace.selectedID == summary.id,
            select: { Task { await workspace.select(summary.id) } },
            rename: { name in
                Task { await workspace.renameSession(summary.id, to: name) }
            },
            delete: { pendingDelete = summary }
        )
        .hoverTip({ anchor in
            var detail = [String]()
            if let harness = summary.harnesses.last {
                detail.append(HarnessBadge.name(for: harness))
            }
            detail.append(summary.updatedAt.formatted(.relative(presentation: .named)))
            return PaneTip(title: summary.title,
                           detail: detail.joined(separator: " · "),
                           state: workspace.state(for: summary.id),
                           anchor: anchor)
        }, update: { scheduleTip($0) })
    }

    private func toggle(_ folder: SidebarGroups.Folder) {
        Task { @MainActor in
            withAnimation(.easeInOut(duration: 0.22)) {
                if toggled.contains(folder.id) { toggled.remove(folder.id) } else { toggled.insert(folder.id) }
            }
        }
    }
}

private struct NsProblemNotice: View {
    let problem: String
    let keepsLastBranches: Bool

    private var consequence: String {
        keepsLastBranches
            ? "As branches mostradas são as da última resposta e podem estar desatualizadas."
            : "As sessões continuam aqui; as branches voltam quando o ns responder."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("ns indisponível")
                .font(.system(size: 12, weight: .semibold))
            Text("\(problem). \(consequence)")
                .font(.system(size: 12))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Theme.alertText)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.alertFill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .strokeBorder(Theme.alertBorder, lineWidth: 1))
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
    }
}
