import Testing
import Foundation
@testable import Den

@Test func devKeepsItsFilesApartFromProduction() {
    let environment = DevEnvironment()
    let support = URL.applicationSupportDirectory.appending(path: "Den Dev")

    #expect(environment.sessionsRoot == support.appending(path: "sessions"))
    #expect(environment.attachmentsRoot == support.appending(path: "attachments"))
    #expect(environment.pullRequestsFile == support.appending(path: "pull-requests.json"))
    #expect(environment.workingDirectory.path == NSHomeDirectory())
    #expect(environment.registry.ids == HarnessRegistry.standard.ids)
}

@Test func devPreferencesNeverReachProduction() {
    let environment = DevEnvironment()
    let key = "DenTests.devIsolation." + UUID().uuidString
    defer { environment.defaults.removeObject(forKey: key) }

    environment.defaults.set("dev", forKey: key)

    #expect(environment.defaults != .standard)
    #expect(environment.defaults.string(forKey: key) == "dev")
    #expect(UserDefaults.standard.object(forKey: key) == nil)
}

@Test func devHandsOutOneDefaultsObject() {
    let environment = DevEnvironment()
    let first = environment.defaults

    #expect(environment.defaults === first)
}

@Test func devReadsTheNsConfigFolderFromItsPreferences() {
    let scratch = ScratchDefaults()
    defer { scratch.remove() }
    let environment = DevEnvironment(defaults: scratch.defaults)

    #expect(environment.nsConfigDirectory == nil)
    scratch.defaults.set("", forKey: NsConfigFolder.key)
    #expect(environment.nsConfigDirectory == nil)
    scratch.defaults.set("~/.config/ns-dev", forKey: NsConfigFolder.key)
    #expect(environment.nsConfigDirectory == "~/.config/ns-dev")
}
