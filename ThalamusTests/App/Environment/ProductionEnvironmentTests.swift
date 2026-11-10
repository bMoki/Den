import Testing
import Foundation
@testable import Thalamus

@Test func productionUsesTheRealPlaces() {
    let environment = ProductionEnvironment()

    #expect(environment.defaults == .standard)
    #expect(environment.sessionsRoot
            == URL.applicationSupportDirectory.appending(path: "Thalamus/sessions"))
    #expect(environment.attachmentsRoot
            == URL.applicationSupportDirectory.appending(path: "Thalamus/attachments"))
    #expect(environment.pullRequestsFile
            == URL.applicationSupportDirectory.appending(path: "Thalamus/pull-requests.json"))
    #expect(environment.workingDirectory.path == NSHomeDirectory())
    #expect(environment.registry.ids == HarnessRegistry.standard.ids)
    #expect(environment.ghOverride == nil)
}

@Test func productionHasNoNsConfigFolder() {
    #expect(ProductionEnvironment().nsConfigDirectory == nil)
}

@Test func productionMigratesFromTheRealDen() {
    #expect(ProductionEnvironment().migration
            == DenMigration(denFolder: URL.applicationSupportDirectory.appending(path: "Den"),
                            denDomain: "gabrielpassos.Den",
                            folder: URL.applicationSupportDirectory.appending(path: "Thalamus")))
}
