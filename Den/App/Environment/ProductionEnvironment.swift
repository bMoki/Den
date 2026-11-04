import Foundation

struct ProductionEnvironment: AppEnvironment {
    private let support = URL.applicationSupportDirectory.appending(path: "Den")

    var sessionsRoot: URL { support.appending(path: "sessions") }
    var attachmentsRoot: URL { support.appending(path: "attachments") }
    var worktreesFile: URL { support.appending(path: "task-worktrees.json") }
    var defaults: UserDefaults { .standard }
    var registry: HarnessRegistry { .standard }
    var workingDirectory: URL { URL(fileURLWithPath: NSHomeDirectory()) }
}
