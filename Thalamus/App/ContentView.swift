import SwiftUI
import HarnessCore

struct ContentView: View {
    @State private var workspace: WorkspaceModel
    @Environment(NsWorkspace.self) private var ns
    @Environment(PanelTerminals.self) private var terminals

    @State private var gitChanges = GitChangesModel()
    @State private var files = FileTree()
    @State private var editors = EditorTabs(windows: .shared)

    @State private var isFullScreen = false

    @AppStorage(PreferenceKey.named("sidebarVisible")) private var sidebarVisible = true
    @AppStorage(PreferenceKey.named("sidebarWidth")) private var sidebarWidth: Double = 280

    init(environment: any AppEnvironment) {
        _workspace = State(initialValue: WorkspaceModel.live(environment))
    }

    var body: some View {
        HStack(spacing: 0) {
            if sidebarVisible {
                SidebarView(workspace: workspace, lightsInset: lightsInset,
                            collapse: toggleSidebar)
                    .frame(width: sidebarWidth)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                ResizeHandle(width: $sidebarWidth, range: 220...380)
            }
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environment(\.chrome, Chrome(
                    leadingInset: sidebarVisible ? 0 : lightsInset,
                    sidebarHidden: !sidebarVisible,
                    showSidebar: toggleSidebar))
        }
        .background(Theme.canvas)
        .foregroundStyle(Theme.text)
        .tint(Theme.accent)
        .ignoresSafeArea()
        .background(WindowChrome(isFullScreen: $isFullScreen))
        .background(WindowCloseGuard {
            UnsavedAlert.confirm("Salvar as alterações antes de fechar a janela?", unsaved: editors.unsaved()) { editors.settle($0) }
        })
        .preferredColorScheme(.dark)
        .frame(minWidth: 860, minHeight: 560)
        .task { await workspace.refresh() }
        .onChange(of: workspace.summaries) { closeVanishedPage() }
        .onChange(of: ns.status) {
            closeVanishedPage()
            closeRemovedBranches()
        }
        .sheet(item: Binding(get: { ns.updateReports.first }, set: { if $0 == nil { ns.dismissUpdateReport() } })) { report in
            BranchUpdateSheet(report: report, close: ns.dismissUpdateReport)
        }
    }

    private func closeRemovedBranches() {
        for row in ns.status?.removed(among: terminals.rows.union(editors.rows)) ?? [] {
            terminals.close(row)
            editors.close(row)
        }
    }

    private func closeVanishedPage() {
        workspace.closePageIfGone(from: workspace.groups(in: ns), statusKnown: ns.status != nil)
    }

    private var lightsInset: CGFloat { isFullScreen ? 0 : Theme.trafficLightsInset }

    private func toggleSidebar() {
        withAnimation(.easeInOut(duration: 0.2)) { sidebarVisible.toggle() }
    }

    @ViewBuilder
    private var detail: some View {
        if let page = workspace.page {
            RowPageView(row: page, workspace: workspace, gitChanges: gitChanges, files: files, editors: editors)
        } else if let chat = workspace.active {
            ChatView(chat: chat, gitChanges: gitChanges, files: files, editors: editors,
                     openPage: workspace.showPage)
        } else if workspace.selectedID != nil {
            sessionLoading
        } else {
            empty
        }
    }

    private func startFirstConversation() {
        Task { await workspace.newSession() }
    }

    @State private var loadingSpinnerVisible = false

    private var sessionLoading: some View {
        VStack(spacing: 0) {
            EmptyHeader()
            ProgressView()
                .controlSize(.small)
                .opacity(loadingSpinnerVisible ? 1 : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("")
        .task {
            loadingSpinnerVisible = false
            try? await Task.sleep(for: .milliseconds(400))
            loadingSpinnerVisible = true
        }
    }

    private var empty: some View {
        VStack(spacing: 0) {
            EmptyHeader()
            VStack(spacing: 14) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 68, height: 68)
                    .background(Theme.raised, in: RoundedRectangle(cornerRadius: 16,
                                                                   style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Theme.borderStrong, lineWidth: 1))
                VStack(spacing: 4) {
                    Text("Nenhuma conversa aberta")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Comece uma sessão nova ou abra uma branch ou pasta na barra lateral.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textTertiary)
                }
                Button { startFirstConversation() } label: {
                    Label("Nova conversa", systemImage: "plus")
                        .labelStyle(.titleAndIcon)
                        .pillLabel()
                }
                .buttonStyle(.thalamusPrimary)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("")
    }
}

struct Chrome {
    var leadingInset: CGFloat = 0
    var sidebarHidden = false
    var showSidebar: () -> Void = {}

    var headerInset: CGFloat { leadingInset + (sidebarHidden ? 8 : 20) }
}

extension EnvironmentValues {
    @Entry var chrome = Chrome()
}

struct SidebarToggle: View {
    @Environment(\.chrome) private var chrome

    var body: some View {
        if chrome.sidebarHidden {
            SidebarButton(title: "Mostrar barra lateral", action: chrome.showSidebar)
        }
    }
}

struct SidebarButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "sidebar.left")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textMuted)
                .iconLabel()
        }
        .buttonStyle(.thalamusGhost)
        .help(title)
        .accessibilityLabel(title)
    }
}

private struct EmptyHeader: View {
    @Environment(\.chrome) private var chrome

    var body: some View {
        TopBar(leadingInset: chrome.leadingInset + 12) {
            SidebarToggle()
            Spacer()
        }
    }
}

#Preview {
    let environment = DevEnvironment()
    ContentView(environment: environment)
        .environment(PullRequestMonitor(ledger: PullRequestLedger(store: PullRequestStore(url: environment.pullRequestsFile)),
                                        fetcher: GitHubCLI()))
        .environment(PanelTerminals())
        .defaultAppStorage(environment.defaults)
}
