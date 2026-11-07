import Testing
import Foundation
import HarnessCore
@testable import Den

private let harness = HarnessID(rawValue: "test-harness")
private let other = HarnessID(rawValue: "other-harness")

@Test func catalogRoundTripsPerDirectory() {
    withTemporaryCache { cache in
        let directory = URL(fileURLWithPath: "/tmp/den-tests/project")
        let catalog = CommandCatalog(skills: ["review"], supportsCompact: true)
        cache.remember(catalog, for: directory, harness: harness)
        #expect(cache.rememberedCatalog(for: directory, harness: harness) == catalog)
    }
}

@Test func catalogsOfDifferentDirectoriesNeverBleed() {
    withTemporaryCache { cache in
        let one = URL(fileURLWithPath: "/tmp/den-tests/one")
        let two = URL(fileURLWithPath: "/tmp/den-tests/two")
        let first = CommandCatalog(skills: ["review"], supportsCompact: true)
        let second = CommandCatalog(skills: ["deploy"], supportsCompact: false)

        cache.remember(first, for: one, harness: harness)
        cache.remember(second, for: two, harness: harness)

        #expect(cache.rememberedCatalog(for: one, harness: harness) == first)
        #expect(cache.rememberedCatalog(for: two, harness: harness) == second)
    }
}

@Test func catalogFallsBackToTheLastOneForNewDirectories() {
    withTemporaryCache { cache in
        let known = URL(fileURLWithPath: "/tmp/den-tests/known")
        let fresh = URL(fileURLWithPath: "/tmp/den-tests/fresh")
        let catalog = CommandCatalog(skills: ["review"], supportsCompact: true)
        cache.remember(catalog, for: known, harness: harness)
        #expect(cache.rememberedCatalog(for: fresh, harness: harness) == catalog)
        #expect(cache.rememberedCatalog(for: fresh, harness: other) == .empty)
    }
}

@Test func emptyCatalogNeverOverwritesARememberedOne() {
    withTemporaryCache { cache in
        let directory = URL(fileURLWithPath: "/tmp/den-tests/project")
        let catalog = CommandCatalog(skills: ["review"], supportsCompact: true)
        cache.remember(catalog, for: directory, harness: harness)
        cache.remember(.empty, for: directory, harness: harness)
        #expect(cache.rememberedCatalog(for: directory, harness: harness) == catalog)
    }
}

@Test func knobsRoundTripPerHarness() {
    withTemporaryCache { cache in
        let knobs = [HarnessKnob(id: "model", category: .model, name: "Modelo",
                                 currentValue: "opus",
                                 options: [.init(value: "opus", label: "Opus")])]
        cache.remember(knobs, for: harness)
        #expect(cache.rememberedKnobs(for: harness) == knobs)
        #expect(cache.rememberedKnobs(for: other) == [])

        cache.remember([], for: harness)
        #expect(cache.rememberedKnobs(for: harness) == knobs)
    }
}

@Test func preferencesAreKeptPerSessionAndHarness() {
    withTemporaryCache { cache in
        let session = UUID()
        #expect(cache.preferences(for: session, harness: harness) == nil)

        cache.setPreferences(["model": "opus"], for: session, harness: harness)
        #expect(cache.preferences(for: session, harness: harness) == ["model": "opus"])
        #expect(cache.preferences(for: session, harness: other) == nil)
        #expect(cache.preferences(for: UUID(), harness: harness) == nil)

        cache.setPreferences([:], for: session, harness: harness)
        #expect(cache.preferences(for: session, harness: harness) == [:])
    }
}

@Test func forgettingASessionDropsItsChoicesOnEveryHarness() {
    withTemporaryCache { cache in
        let session = UUID()
        let kept = UUID()
        cache.setPreferences(["model": "opus"], for: session, harness: harness)
        cache.setPreferences([:], for: session, harness: other)
        cache.setPreferences(["model": "haiku"], for: kept, harness: harness)

        cache.forgetPreferences(of: session)

        #expect(cache.preferences(for: session, harness: harness) == nil)
        #expect(cache.preferences(for: session, harness: other) == nil)
        #expect(cache.preferences(for: kept, harness: harness) == ["model": "haiku"])
    }
}

@Test func choicesSavedBeforeThePerHarnessFormatMoveToTheFirstHarnessThatSavesThem() {
    withTemporaryCache { cache in
        let session = UUID()
        cache.defaults.set([session.uuidString: ["model": "opus"]], forKey: "Den.sessionPreferences")
        #expect(cache.preferences(for: session, harness: harness) == ["model": "opus"])

        cache.setPreferences(["model": "opus"], for: session, harness: harness)

        #expect(cache.preferences(for: session, harness: other) == nil)
        #expect(cache.defaults.dictionary(forKey: "Den.sessionPreferences")?.isEmpty == true)
    }
}

private let modelKnob = HarnessKnob(
    id: "model", category: .model, name: "Modelo",
    options: [.init(value: "opus", label: "Opus"), .init(value: "haiku", label: "Haiku")])
private let modeKnob = HarnessKnob(
    id: "mode", category: .mode, name: "Modo", options: [.init(value: "auto", label: "Auto")])

@Test func theSessionDefaultIsKeptPerHarnessAndClearsBackToTheHarnessOwn() {
    withTemporaryCache { cache in
        cache.setSessionDefault("opus", knob: "model", for: harness)
        cache.setSessionDefault("auto", knob: "mode", for: harness)
        #expect(cache.sessionDefault(for: harness) == ["model": "opus", "mode": "auto"])
        #expect(cache.sessionDefault(for: other) == [:])

        cache.setSessionDefault(nil, knob: "model", for: harness)
        #expect(cache.sessionDefault(for: harness) == ["mode": "auto"])
    }
}

@Test func aSessionDefaultTheHarnessNoLongerOffersIsDroppedAndTheRestStays() {
    withTemporaryCache { cache in
        cache.setSessionDefault("gone", knob: "model", for: harness)
        cache.setSessionDefault("auto", knob: "mode", for: harness)
        cache.setSessionDefault("high", knob: "effort", for: harness)

        #expect(cache.offeredSessionDefault(for: harness, among: [modelKnob, modeKnob]) == ["mode": "auto"])
    }
}

@Test func separateCachesNeverSeeEachOther() {
    let directory = URL(fileURLWithPath: "/tmp/den-tests/project")
    let catalog = CommandCatalog(skills: ["review"], supportsCompact: true)
    withTemporaryCache { first in
        first.remember(catalog, for: directory, harness: harness)
        withTemporaryCache { second in
            #expect(second.rememberedCatalog(for: directory, harness: harness) == .empty)
        }
        #expect(first.rememberedCatalog(for: directory, harness: harness) == catalog)
    }
}
