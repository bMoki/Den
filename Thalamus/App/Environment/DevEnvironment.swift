import Foundation

struct DevEnvironment: AppEnvironment {
    static let defaultsSuite = "Den.Dev"

    private let support = URL.applicationSupportDirectory.appending(path: "Den Dev")

    let defaults: UserDefaults

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? UserDefaults(suiteName: Self.defaultsSuite) ?? .standard
    }

    var sessionsRoot: URL { support.appending(path: "sessions") }
    var attachmentsRoot: URL { support.appending(path: "attachments") }
    var pullRequestsFile: URL { support.appending(path: "pull-requests.json") }
    var registry: HarnessRegistry { .standard }
    var workingDirectory: URL { URL(fileURLWithPath: NSHomeDirectory()) }
    var nsConfigDirectory: String? { preference(NsConfigFolder.key) }
}
