import Foundation

public protocol HarnessSession: Actor {

    func start(_ start: SessionStart) async throws -> AsyncStream<SessionUpdate>

    func send(_ turn: UserTurn) async throws

    func resolve(_ requestID: String, _ decision: PermissionDecision) async throws

    func interrupt() async throws

    func apply(knob id: String, value: String?) async throws

    func knobs() async -> [HarnessKnob]

    func contextUsage() async -> ContextUsage?

    func stop() async

    func withdraw(_ turnID: UUID) async -> Bool
}

public extension HarnessSession {
    func contextUsage() async -> ContextUsage? { nil }

    func withdraw(_ turnID: UUID) async -> Bool { false }
}
