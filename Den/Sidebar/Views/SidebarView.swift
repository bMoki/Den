import SwiftUI
import HarnessCore

struct SidebarView: View {
    @Bindable var workspace: WorkspaceModel
    @Environment(WorktreeModel.self) private var worktrees
    @Environment(PullRequestMonitor.self) private var monitor
    @Environment(NsWorkspace.self) private var ns
    @Environment(PanelTerminals.self) private var terminals
    var lightsInset: CGFloat = 0
    var collapse: () -> Void = {}

    @State private var toggled: Set<String> = []
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
            Button("Apagar", role: .destructive) {
                if let summary = pendingDelete {
                    Task { await workspace.deleteSession(summary.id) }
                    worktrees.forget(summary.id)
                    terminals.close(sessionID: summary.id)
                }
                pendingDelete = nil
            }
            Button("Cancelar", role: .cancel) { pendingDelete = nil }
        } message: {
            Text(deleteMessage)
        }
        .sheet(isPresented: Binding(
            get: { ns.creation?.isPresented == true },
            set: { if !$0 { ns.creation?.isPresented = false } }
        )) {
            if let creation = ns.creation {
                NewBranchSheet(creation: creation) { create(with: creation) }
            }
        }
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
        SidebarGroups(sessions: workspace.summaries, status: ns.status, search: workspace.search)
    }

    private var list: some View {
        let groups = groups
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 1) {
                if let problem = ns.problem {
                    NsProblemNotice(problem: problem, keepsLastBranches: ns.status != nil)
                }

                if ns.status != nil {
                    sectionTitle("Branches de workspace") {
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
                    ForEach(groups.branches) { folder($0, isBranch: true) }
                }

                if !groups.baseRepos.isEmpty {
                    sectionTitle("Repos base") { EmptyView() }
                        .padding(.top, 14)
                    ForEach(groups.baseRepos) { folder($0) }
                }

                sectionTitle("Outras pastas") {
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
                .padding(.top, ns.status == nil ? 0 : 14)
                ForEach(groups.otherFolders) { folder($0, detail: Self.parent(of: $0.path)) }

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
        .onChange(of: workspace.summaries, initial: true) {
            monitor.noteActivity(Dictionary(workspace.summaries.map { ($0.id, $0.updatedAt) },
                                            uniquingKeysWith: { max($0, $1) }))
        }
    }

    private func sectionTitle(_ title: String,
                              @ViewBuilder trailing: () -> some View) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textTertiary)
            Spacer(minLength: 0)
            trailing()
        }
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .frame(height: 28)
    }

    private func isOpen(_ folder: SidebarGroups.Folder) -> Bool {
        let opensByDefault = !folder.sessions.isEmpty
        let flipped = toggled.contains(folder.id)
        return !workspace.search.isEmpty || (flipped ? !opensByDefault : opensByDefault)
    }

    @ViewBuilder
    private func folder(_ folder: SidebarGroups.Folder, isBranch: Bool = false,
                        detail: String? = nil) -> some View {
        let isOpen = isOpen(folder)
        Group {
            if isBranch {
                BranchHeader(
                    name: folder.name,
                    branch: ns.branch(named: folder.name),
                    activity: ns.activity[folder.name],
                    problem: ns.actionProblems[folder.name],
                    sessionCount: folder.sessions.count,
                    isOpen: isOpen,
                    toggle: { toggle(folder) },
                    newSession: { Task { await workspace.newSession(in: folder.path) } },
                    start: { Task { await ns.start(folder.name) } },
                    stop: { Task { await ns.stop(folder.name) } },
                    update: { Task { await ns.update(folder.name) } }
                )
            } else {
                FolderHeader(
                    name: folder.name,
                    detail: detail,
                    sessionCount: folder.sessions.count,
                    isOpen: isOpen,
                    toggle: { toggle(folder) },
                    newSession: { Task { await workspace.newSession(in: folder.path) } }
                )
            }
        }
        .hoverTip({ anchor in
            PaneTip(title: folder.name,
                    detail: tipDetail(for: folder, isBranch: isBranch),
                    indicator: nil, anchor: anchor)
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

    private func badge(for summary: SessionSummary) -> TaskBadge? {
        worktrees.worktree(for: summary.id).map {
            TaskBadge.make(worktree: $0, pullRequests: monitor.pullRequests(for: summary.id).map(\.pullRequest))
        }
    }

    private func hoverLines(for summary: SessionSummary) -> [PaneTip.Line] {
        worktrees.worktree(for: summary.id).map {
            PaneTip.Line.task($0, bars: monitor.pullRequests(for: summary.id))
        } ?? []
    }

    private var deleteMessage: String {
        var text = "A conversa e o histórico dela serão removidos permanentemente."
        if let summary = pendingDelete, let worktree = worktrees.worktree(for: summary.id) {
            text += " As worktrees em \(worktree.displayLocation) continuam no disco."
        }
        return text
    }

    private func row(for summary: SessionSummary) -> some View {
        SessionRow(
            summary: summary,
            indicator: workspace.indicator(for: summary.id),
            task: badge(for: summary),
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
                           indicator: workspace.indicator(for: summary.id),
                           anchor: anchor,
                           lines: hoverLines(for: summary))
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
