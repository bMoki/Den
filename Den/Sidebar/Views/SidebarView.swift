import SwiftUI
import HarnessCore

struct SidebarView: View {
    @Bindable var workspace: WorkspaceModel
    @Environment(PullRequestMonitor.self) private var monitor
    @Environment(NsWorkspace.self) private var ns
    var lightsInset: CGFloat = 0
    var collapse: () -> Void = {}

    @State private var tipTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            SidebarHeader(workspace: workspace, lightsInset: lightsInset, collapse: collapse)
            SidebarSearch(workspace: workspace)
            list
        }
        .background(Theme.sidebar)
        .sheet(isPresented: Binding(
            get: { ns.creation?.isPresented == true },
            set: { if !$0 { ns.creation?.isPresented = false } }
        )) {
            if let creation = ns.creation {
                NewBranchSheet(creation: creation, start: { create(with: creation) },
                               retry: { repo in continuing(creation) { await creation.retry(repo) } },
                               prepareAgain: { continuing(creation) { await creation.prepareAgain() } })
            }
        }
        .sheet(item: Binding(get: { ns.removal }, set: { if $0 == nil { ns.cancelRemoval() } })) { removal in
            RemoveBranchSheet(removal: removal, editors: .shared, root: ns.root(of: .branch(removal.branch)),
                              cancel: ns.cancelRemoval) { purge in
                guard EditorWindows.shared.unsaved(in: .branch(removal.branch)).isEmpty else { return }
                Task { await ns.remove(removal.branch, purge: purge) }
            }
        }
    }

    private func continuing(_ creation: BranchCreation, _ work: @escaping @MainActor () async -> Void) {
        Task { await ns.holdingBranch(of: creation, while: work) }
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
        workspace.groups(in: ns, search: workspace.search)
    }

    private var list: some View {
        let groups = groups
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                if let problem = ns.problem {
                    NsProblemNotice(problem: problem, keepsLastBranches: ns.status != nil)
                }

                if !groups.favorites.isEmpty {
                    section(.favorites, in: groups) { EmptyView() }
                }

                if ns.status != nil {
                    section(.branches, in: groups, top: groups.favorites.isEmpty ? 0 : 14) {
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
                }

                if !groups.baseRepos.isEmpty {
                    section(.baseRepos, in: groups, top: 14) { EmptyView() }
                }

                section(.otherFolders, in: groups, top: ns.status == nil && groups.favorites.isEmpty ? 0 : 14) {
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

                if !groups.archived.isEmpty {
                    ArchivedRow(count: groups.archived.count, isSelected: selectedRow == .archived) {
                        workspace.showPage(.archived)
                    }
                    .padding(.top, 14)
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
    private func section(_ group: SidebarGroup, in groups: SidebarGroups, top: CGFloat = 0,
                         @ViewBuilder actions: @escaping () -> some View) -> some View {
        let searching = !workspace.search.isEmpty
        let folders = groups[group]
        let shown = workspace.layout.shown(folders, in: group, focus: selectedRow, searching: searching)
        SidebarCollapsibleTitle(title: group.title, hidden: folders.count - shown.count,
                                isExpanded: workspace.layout.isExpanded(group, searching: searching),
                                isEnabled: !searching, toggle: { workspace.layout.toggleCollapsed(group) },
                                actions: actions)
            .padding(.top, top)
        ForEach(shown) { folder($0).transition(.opacity) }
    }

    private var selectedRow: SidebarRow? {
        if let page = workspace.page { return page }
        guard let id = workspace.selectedID,
              let summary = workspace.summaries.first(where: { $0.id == id }) else { return nil }
        return ns.row(of: summary.workingDirectory)
    }

    private func open(_ folder: SidebarGroups.Folder) {
        let row = SidebarRow(folder)
        let sessions = workspace.groups(in: ns).folder(row)?.sessions ?? []
        Task { await workspace.open(row, among: sessions, reselected: selectedRow == row) }
    }

    @ViewBuilder
    private func folder(_ folder: SidebarGroups.Folder) -> some View {
        let isSelected = selectedRow == SidebarRow(folder)
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
                    pullRequests: monitor.bars(for: folder.name).map(\.pullRequest),
                    sessions: workspace.tally(folder.sessions),
                    isSelected: isSelected,
                    open: { open(folder) },
                    newSession: { Task { await workspace.newSession(in: folder.path) } },
                    start: { Task { await ns.start(folder.name) } },
                    stop: { Task { await ns.stop(folder.name) } },
                    update: { Task { await ns.update(folder.name) } },
                    addableRepos: ns.addableRepos(of: folder.name),
                    addRepo: { repo in Task { await ns.addRepo(repo, to: folder.name) } },
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
                    isSelected: isSelected,
                    open: { open(folder) },
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
                    lines: isBranch ? PaneTip.Line.pullRequests(monitor.bars(for: folder.name)) : [])
        }, update: { scheduleTip($0) })
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
