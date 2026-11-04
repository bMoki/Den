import SwiftUI

@main
struct DenApp: App {
    private let environment: any AppEnvironment
    @State private var worktrees: WorktreeModel
    @State private var monitor: PullRequestMonitor

    init() {
        let environment = resolveEnvironment(ProcessInfo.processInfo.environment)
        self.environment = environment
        let ledger = TaskLedger(store: TaskWorktreeStore(url: environment.worktreesFile))
        _worktrees = State(initialValue: WorktreeModel(ledger: ledger))
        _monitor = State(initialValue: PullRequestMonitor(
            ledger: ledger,
            fetcher: GitHubCLI(override: environment.ghOverride,
                               configured: environment.defaults.string(forKey: GitHubCLI.pathKey))))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(environment: environment)
                .environment(worktrees)
                .environment(monitor)
                .defaultAppStorage(environment.defaults)
                .task { monitor.start() }
        }

        .commands { HarnessCommands() }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 800)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
                .environment(monitor)
                .defaultAppStorage(environment.defaults)
        }
    }
}
