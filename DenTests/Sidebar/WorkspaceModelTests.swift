import Testing
import Foundation
import HarnessCore
@testable import Den

// MARK: - Sessions backed by the store

@Test func selectRestoresAChatWithoutBringingItToLife() async throws {
    try await withWorkspace { harness in
        let session = storedSession("restored")
        try await harness.store.saveMetadata(session)
        await harness.model.refresh()

        await harness.model.select(session.id)

        #expect(harness.model.selectedID == session.id)
        #expect(harness.model.active?.title == "restored")
        #expect(harness.model.isLive(session.id) == false)
    }
}

@Test func stateRanksWhatNeedsAttentionFirst() async throws {
    try await withWorkspace { harness in
        let session = storedSession("busy")
        try await harness.store.saveMetadata(session)
        await harness.model.select(session.id)
        let chat = try #require(harness.model.active)

        #expect(harness.model.state(for: session.id) == nil)

        chat.isBusy = true
        #expect(harness.model.state(for: session.id) == .thinking)

        chat.hasUnread = true
        #expect(harness.model.state(for: session.id) == .newReply)

        chat.isRateLimited = true
        #expect(harness.model.state(for: session.id) == .outOfTokens)

        chat.pending = PermissionRequest(id: "p1", toolName: "Bash",
                                         input: .object([:]), options: [])
        #expect(harness.model.state(for: session.id) == .awaitingDecision)

        chat.pending = nil
        chat.pendingQuestion = nil
        chat.isRateLimited = false
        chat.hasUnread = false
        #expect(harness.model.state(for: session.id) == .thinking)
    }
}

@Test func stateIsQuietForASessionNeverOpened() async throws {
    try await withWorkspace { harness in
        #expect(harness.model.state(for: UUID()) == nil)
        #expect(harness.model.isLive(UUID()) == false)
    }
}

@Test func renameSessionTrimsAndPersists() async throws {
    try await withWorkspace { harness in
        let session = storedSession("before")
        try await harness.store.saveMetadata(session)
        await harness.model.refresh()

        await harness.model.renameSession(session.id, to: "   ")
        #expect(harness.model.summaries.map(\.title) == ["before"])

        await harness.model.renameSession(session.id, to: "  after  ")
        #expect(harness.model.summaries.map(\.title) == ["after"])
    }
}

@Test func deleteSessionClearsEveryTraceOfIt() async throws {
    try await withWorkspace { harness in
        let session = storedSession("doomed")
        try await harness.store.saveMetadata(session)
        await harness.model.refresh()

        harness.model.selectedID = session.id
        let cache = SessionCache(defaults: harness.defaults)
        cache.setPreferences(["model": "opus"], for: session.id, harness: HarnessRegistry.standard.fallback)

        await harness.model.deleteSession(session.id)

        #expect(harness.model.summaries.isEmpty)
        #expect(harness.model.selectedID == nil)
        #expect(cache.preferences(for: session.id, harness: HarnessRegistry.standard.fallback) == nil)
    }
}

// MARK: - Default harness

@Test func theDefaultHarnessRoundTripsThroughTheInjectedDefaults() async throws {
    try await withWorkspace { harness in
        #expect(harness.model.defaultHarness == HarnessRegistry.standard.fallback)

        let target = try #require(harness.model.availableHarnesses.last)
        harness.model.defaultHarness = target
        #expect(harness.model.defaultHarness == target)

        let reopened = WorkspaceModel(store: harness.store, defaults: harness.defaults,
                                      cache: SessionCache(defaults: harness.defaults))
        #expect(reopened.defaultHarness == target)
    }
}

@Test func anUnknownStoredHarnessFallsBack() async throws {
    try await withWorkspace(seed: { defaults in
        defaults.set("ghost-harness", forKey: "Den.defaultHarness")
    }) { harness in
        #expect(harness.model.defaultHarness == HarnessRegistry.standard.fallback)
    }
}

@Test func tallyCountsEverySessionButOnlyLoadedOnesHaveAState() async throws {
    try await withWorkspace { harness in
        let waiting = storedSession("waiting")
        let busy = storedSession("busy")
        let untouched = storedSession("untouched")
        for session in [waiting, busy, untouched] {
            try await harness.store.saveMetadata(session)
        }
        await harness.model.refresh()
        await harness.model.select(busy.id)
        try #require(harness.model.active).isBusy = true
        await harness.model.select(waiting.id)
        try #require(harness.model.active).pending = PermissionRequest(id: "p1", toolName: "Bash",
                                                                       input: .object([:]), options: [])

        let tally = harness.model.tally(harness.model.summaries)
        #expect(tally.total == 3)
        #expect(tally.prevailing?.state == .awaitingDecision)
        #expect(tally.prevailing?.count == 1)
        #expect(harness.model.tally([]) == SessionTally(total: 0, prevailing: nil))
    }
}
