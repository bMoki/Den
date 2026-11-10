import Foundation

struct ProductionEnvironment: AppEnvironment {
    private let support = URL.applicationSupportDirectory.appending(path: "Thalamus")

    var sessionsRoot: URL { support.appending(path: "sessions") }
    var attachmentsRoot: URL { support.appending(path: "attachments") }
    var pullRequestsFile: URL { support.appending(path: "pull-requests.json") }
    var defaults: UserDefaults { .standard }
    var registry: HarnessRegistry { .standard }
    var workingDirectory: URL { URL(fileURLWithPath: NSHomeDirectory()) }
    var migration: DenMigration? {
        DenMigration(denFolder: URL.applicationSupportDirectory.appending(path: "Den"),
                     denDomain: "gabrielpassos.Den", folder: support)
    }
}
