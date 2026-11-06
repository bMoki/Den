import Testing
import Foundation
import HarnessCore
@testable import Den

@MainActor
private func exchange(_ live: LiveChatHarness, _ texts: [String]) async {
    for text in texts {
        await live.chat.send(text: text)
        await live.session.emit(endOfTurn())
        await settle { !live.chat.isBusy }
    }
}

@MainActor
private func queueBehindATurn(_ live: LiveChatHarness, _ text: String) async throws -> UUID {
    await live.chat.send(text: "first")
    await live.chat.send(text: text)
    return try #require(await live.session.sent.last?.id)
}

@MainActor
private func reportQueued(_ live: LiveChatHarness, _ text: String) async throws -> UUID {
    let id = try await queueBehindATurn(live, text)
    await live.session.emit(.event(.messageQueue(turnID: id, state: .waiting)))
    await settle { !queuedLines(live.chat).isEmpty }
    return id
}

@MainActor
private func persists(_ live: LiveChatHarness, _ expected: [String]) async -> Bool {
    let deadline = ContinuousClock.now + .seconds(5)
    while ContinuousClock.now < deadline {
        let session = try? await live.store.load(live.chat.sessionID)
        let texts = (session?.segments ?? []).flatMap(\.entries).compactMap { entry -> String? in
            if case .userMessage(let text, _) = entry.kind { text } else { nil }
        }
        if texts == expected { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return false
}

@MainActor
private func queuedLines(_ chat: ChatModel) -> [String] {
    chat.lines.filter(\.isQueued).map(\.text)
}

@Test func upWalksBackThroughTheSentMessagesAndDownReturnsToTheDraft() async throws {
    try await withLiveChat { live in
        await exchange(live, ["one", "two"])
        live.chat.prompt = "meio escrito"

        await live.chat.recallOlder()
        #expect(live.chat.prompt == "two")
        await live.chat.recallOlder()
        #expect(live.chat.prompt == "one")
        #expect(!live.chat.canRecallOlder)

        live.chat.recallNewer()
        #expect(live.chat.prompt == "two")
        live.chat.recallNewer()
        #expect(live.chat.prompt == "meio escrito")
        #expect(!live.chat.isBrowsingHistory)
    }
}

@Test func sendingARecalledMessageSendsItAsANewOne() async throws {
    try await withLiveChat { live in
        await exchange(live, ["one"])
        await live.chat.recallOlder()

        await live.chat.send()

        #expect(await live.session.sent.map(\.text) == ["one", "one"])
        #expect(live.chat.sentMessages == ["one", "one"])
        #expect(!live.chat.isBrowsingHistory)
    }
}

@Test func theHistoryReachesMessagesFromBeforeTheSessionWasReopened() {
    let root = FileManager.default.temporaryDirectory
        .appending(path: "DenTests-" + UUID().uuidString)
    let asked = TranscriptEntry(timestamp: Date(),
                                kind: .userMessage(text: "/review", attachments: []), raw: .null)
    let segment = Segment(harness: HarnessID(rawValue: "test-" + UUID().uuidString),
                          harnessSessionID: "", model: "", entries: [asked])
    let chat = ChatModel(store: FileTranscriptStore(root: root),
                         restoring: Session(title: "reopened", workingDirectory: root,
                                            segments: [segment]),
                         cache: scratchCache)

    #expect(chat.sentMessages == ["/review"])
}

@Test func aMessageTheHarnessQueuesShowsAsQueuedUntilItIsReceived() async throws {
    try await withLiveChat { live in
        let id = try await queueBehindATurn(live, "second")
        #expect(queuedLines(live.chat).isEmpty)

        await live.session.emit(.event(.messageQueue(turnID: id, state: .waiting)))
        await settle { queuedLines(live.chat) == ["second"] }
        #expect(!live.chat.sentMessages.contains("second"))

        await live.session.emit(.event(.messageQueue(turnID: id, state: .received)))
        await settle { queuedLines(live.chat).isEmpty }
        #expect(await persists(live, ["first", "second"]))
    }
}

@Test func upWithdrawsTheQueuedMessageBackIntoTheComposer() async throws {
    try await withLiveChat { live in
        let id = try await reportQueued(live, "second")
        live.chat.prompt = "draft"

        await live.chat.recallOlder()

        #expect(await live.session.withdrawals == [id])
        #expect(live.chat.prompt == "second\n\ndraft")
        #expect(!live.chat.lines.contains { $0.text == "second" })
        #expect(!live.chat.isBrowsingHistory)
        #expect(await persists(live, ["first"]))
    }
}

@Test func whenTheHarnessAlreadyTookTheMessageUpGoesToTheHistory() async throws {
    try await withLiveChat { live in
        await live.session.answerWithdraw(false)
        let id = try await reportQueued(live, "second")

        await live.chat.recallOlder()

        #expect(await live.session.withdrawals == [id])
        #expect(live.chat.prompt == "second")
        #expect(queuedLines(live.chat).isEmpty)
        #expect(await persists(live, ["first", "second"]))
    }
}

@Test func aQueuedMessageThatStartsAfterTheTurnEndsMarksTheChatBusyAgain() async throws {
    try await withLiveChat { live in
        let id = try await queueBehindATurn(live, "second")
        await live.session.emit(.event(.messageQueue(turnID: id, state: .waiting)))
        await live.session.emit(endOfTurn())
        await settle { !live.chat.isBusy }
        #expect(queuedLines(live.chat) == ["second"])

        await live.session.emit(.event(.messageQueue(turnID: id, state: .received)))

        await settle { live.chat.isBusy }
        #expect(queuedLines(live.chat).isEmpty)
    }
}

@Test func aMessageTheHarnessDropsGoesBackToTheComposer() async throws {
    try await withLiveChat { live in
        let id = try await queueBehindATurn(live, "second")
        await live.session.emit(.event(.messageQueue(turnID: id, state: .waiting)))
        await live.session.emit(.event(.messageQueue(turnID: id, state: .dropped)))

        await settle { live.chat.prompt == "second" }
        #expect(!live.chat.lines.contains { $0.text == "second" })
    }
}

@Test func withoutQueueReportsAMessageSentMidTurnIsKeptWhenTheTurnEnds() async throws {
    try await withLiveChat { live in
        _ = try await queueBehindATurn(live, "second")

        await live.session.emit(endOfTurn())

        await settle { !live.chat.isBusy }
        #expect(queuedLines(live.chat).isEmpty)
        #expect(await persists(live, ["first", "second"]))
        await live.chat.recallOlder()
        #expect(live.chat.prompt == "second")
        #expect(await live.session.withdrawals.isEmpty)
    }
}

@Test func stoppingGivesBackWhatTheHarnessStillHadQueued() async throws {
    try await withLiveChat { live in
        _ = try await reportQueued(live, "second")

        await live.chat.stop()

        #expect(live.chat.prompt == "second")
        #expect(live.chat.composer.queue.isEmpty)
        #expect(await persists(live, ["first"]))
    }
}

@Test func aSecondUpWhileWithdrawingDoesNotAskTwice() async throws {
    try await withLiveChat { live in
        _ = try await reportQueued(live, "second")

        async let first: Void = live.chat.recallOlder()
        async let second: Void = live.chat.recallOlder()
        _ = await (first, second)

        #expect(await live.session.withdrawals.count == 1)
        #expect(live.chat.prompt == "second")
    }
}

@MainActor
private func browseThenReport(_ live: LiveChatHarness, draft: String) async throws -> UUID {
    let id = try await queueBehindATurn(live, "second")
    live.chat.prompt = draft
    await live.chat.recallOlder()
    await live.session.emit(.event(.messageQueue(turnID: id, state: .waiting)))
    await settle { !queuedLines(live.chat).isEmpty }
    return id
}

@Test func upWhileBrowsingTheHistoryLeavesTheQueueAlone() async throws {
    try await withLiveChat { live in
        _ = try await browseThenReport(live, draft: "")

        await live.chat.recallOlder()

        #expect(live.chat.isBrowsingHistory)
        #expect(await live.session.withdrawals.isEmpty)
    }
}

@Test func aDroppedMessageKeepsTheDraftSavedBeforeBrowsing() async throws {
    try await withLiveChat { live in
        let id = try await browseThenReport(live, draft: "draft")
        #expect(live.chat.prompt == "second")

        await live.session.emit(.event(.messageQueue(turnID: id, state: .dropped)))

        await settle { live.chat.prompt == "second\n\ndraft" }
        #expect(!live.chat.isBrowsingHistory)
    }
}

@Test func aReceivedMessageMovesBelowWhatTheAgentSaidMeanwhile() async throws {
    try await withLiveChat { live in
        let id = try await reportQueued(live, "second")
        await live.session.emit(assistant("still working"))
        await live.session.emit(.event(.messageQueue(turnID: id, state: .received)))

        await settle { live.chat.lines.last?.text == "second" }
        #expect(await persists(live, ["first", "second"]))
    }
}

@Test func aQueuedMessageThatFailsToSendGoesBackToTheComposer() async throws {
    try await withLiveChat { live in
        await live.chat.send(text: "first")
        await live.session.failSend(HarnessFailure(reason: "pipe closed"))

        await live.chat.send(text: "second")

        #expect(live.chat.prompt == "second")
        #expect(!live.chat.lines.contains { $0.text == "second" })
    }
}
