import Testing
import Foundation
import HarnessCore

private actor BareSession: HarnessSession {
    func start(_ start: SessionStart) async throws -> AsyncStream<SessionUpdate> { AsyncStream { $0.finish() } }
    func send(_ turn: UserTurn) async throws {}
    func resolve(_ requestID: String, _ decision: PermissionDecision) async throws {}
    func interrupt() async throws {}
    func apply(knob id: String, value: String?) async throws {}
    func knobs() async -> [HarnessKnob] { [] }
    func stop() async {}
}

@Test func aSessionThatCannotWithdrawLeavesTheQueuedMessageWithTheHarness() async {
    #expect(await BareSession().withdraw(UUID()) == false)
}
