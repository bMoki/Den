import SwiftUI

@main
struct ThalamusApp: App {
    @NSApplicationDelegateAdaptor private var delegate: ThalamusAppDelegate
    private let environment: any AppEnvironment
    @State private var monitor: PullRequestMonitor
    @State private var ns: NsWorkspace
    @State private var terminals = PanelTerminals()

    init() {
        let environment = resolveEnvironment(ProcessInfo.processInfo.environment)
        self.environment = environment
        NsConfigFolder.export(environment.nsConfigDirectory)
        _ns = State(initialValue: NsWorkspace.live(environment))
        _monitor = State(initialValue: PullRequestMonitor(
            ledger: PullRequestLedger(store: PullRequestStore(url: environment.pullRequestsFile)),
            fetcher: GitHubCLI(override: environment.ghOverride,
                               configured: environment.defaults.string(forKey: GitHubCLI.pathKey))))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(environment: environment)
                .environment(monitor)
                .environment(ns)
                .environment(terminals)
                .defaultAppStorage(environment.defaults)
                .task { monitor.start() }
                .task { await ns.watch() }
                .task(id: ns.status) { await track(ns.status) }
        }

        .commands { HarnessCommands() }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 800)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView(defaults: environment.defaults)
                .environment(monitor)
                .defaultAppStorage(environment.defaults)
        }
    }

    private func track(_ status: NsStatus?) async {
        guard let status else { return }
        let repos = await Task.detached { BranchRepo.list(in: status) }.value
        guard !Task.isCancelled else { return }
        monitor.track(repos, branches: Set(status.branches.map(\.branch)))
    }
}

final class ThalamusAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let leaves = UnsavedAlert.confirm("Salvar as alterações antes de sair?", unsaved: EditorWindows.shared.unsaved()) {
            EditorWindows.shared.settle($0)
        }
        return leaves ? .terminateNow : .terminateCancel
    }
}
