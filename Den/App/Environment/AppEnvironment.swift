import Foundation

protocol AppEnvironment {
    var sessionsRoot: URL { get }
    var attachmentsRoot: URL { get }
    var worktreesFile: URL { get }
    var ghOverride: String? { get }
    var nsOverride: String? { get }
    var defaults: UserDefaults { get }
    var registry: HarnessRegistry { get }
    var workingDirectory: URL { get }
}

extension AppEnvironment {
    var ghOverride: String? { nil }
    var nsOverride: String? { defaults.string(forKey: NsClient.pathKey).flatMap { $0.isEmpty ? nil : $0 } }
}

protocol RootedEnvironment: AppEnvironment {
    var root: URL { get }
}

extension RootedEnvironment {
    var sessionsRoot: URL { root.appending(path: "sessions") }
    var attachmentsRoot: URL { root.appending(path: "attachments") }
    var worktreesFile: URL { root.appending(path: "task-worktrees.json") }
    var workingDirectory: URL { root.appending(path: "project") }
}

#if DEBUG
let isDebugBuild = true
#else
let isDebugBuild = false
#endif

func resolveEnvironment(_ variables: [String: String],
                        debugBuild: Bool = isDebugBuild) -> any AppEnvironment {
    guard debugBuild else { return ProductionEnvironment() }
    return UITestEnvironment(variables) ?? DevEnvironment()
}
