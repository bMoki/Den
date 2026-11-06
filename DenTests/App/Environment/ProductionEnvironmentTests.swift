import Testing
import Foundation
@testable import Den

@Test func productionUsesTheRealPlaces() {
    let environment = ProductionEnvironment()

    #expect(environment.defaults == .standard)
    #expect(environment.sessionsRoot
            == URL.applicationSupportDirectory.appending(path: "Den/sessions"))
    #expect(environment.attachmentsRoot == ChatModel.standardAttachmentsRoot)
    #expect(environment.pullRequestsFile
            == URL.applicationSupportDirectory.appending(path: "Den/pull-requests.json"))
    #expect(environment.workingDirectory.path == NSHomeDirectory())
    #expect(environment.registry.ids == HarnessRegistry.standard.ids)
    #expect(environment.ghOverride == nil)
}

@Test func productionHasNoNsConfigFolder() {
    #expect(ProductionEnvironment().nsConfigDirectory == nil)
}
