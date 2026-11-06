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

@Test func indicatorRanksRateLimitAboveTheRest() async throws {
    try await withWorkspace { harness in
        let session = storedSession("busy")
        try await harness.store.saveMetadata(session)
        await harness.model.select(session.id)
        let chat = try #require(harness.model.active)

        #expect(harness.model.indicator(for: session.id) == nil)

        chat.hasUnread = true
        #expect(harness.model.indicator(for: session.id) == .unread)

        chat.isBusy = true
        #expect(harness.model.indicator(for: session.id) == .working)

        chat.pendingQuestion = nil
        chat.pending = PermissionRequest(id: "p1", toolName: "Bash",
                                         input: .object([:]), options: [])
        #expect(harness.model.indicator(for: session.id) == .waiting)

        chat.isRateLimited = true
        #expect(harness.model.indicator(for: session.id) == .rateLimited)
    }
}

@Test func indicatorIsQuietForASessionNeverOpened() async throws {
    try await withWorkspace { harness in
        #expect(harness.model.indicator(for: UUID()) == nil)
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

        await harness.model.deleteSession(session.id)

        #expect(harness.model.summaries.isEmpty)
        #expect(harness.model.selectedID == nil)
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
