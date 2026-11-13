import SwiftUI

struct PullRequestBars: View {
    let branch: String

    @Environment(PullRequestMonitor.self) private var monitor
    @AppStorage(GitHubCLI.pathKey) private var ghPath = ""

    var body: some View {
        let bars = monitor.bars(for: branch)
        let setup = monitor.setupNeeded(for: branch)
        if setup != nil || !bars.isEmpty {
            VStack(spacing: Theme.space(.s6)) {
                if let setup {
                    GitHubSetupBar(state: setup, choose: chooseGh,
                                   retry: { Task { await monitor.reconfigure(path: ghPath.isEmpty ? nil : ghPath) } },
                                   dismiss: { monitor.hideSetup(for: branch) })
                }
                ForEach(bars) { bar in
                    PullRequestBar(repo: bar.repo,
                                   pullRequest: bar.pullRequest,
                                   checkedAt: monitor.checkedAt(bar.repo),
                                   refresh: { monitor.refresh(bar.repo) },
                                   dismiss: {
                                       withAnimation(.easeOut(duration: 0.2)) {
                                           monitor.dismiss(bar.repo)
                                       }
                                   })
                                   .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .aboveComposer(fade: 0.25)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: bars.map(\.id))
        }
    }

    private func chooseGh() {
        Task {
            if let chosen = await GhPathPicker.pick(for: monitor) { ghPath = chosen }
        }
    }
}
