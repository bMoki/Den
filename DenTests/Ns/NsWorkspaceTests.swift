import Foundation
import Testing
@testable import Den

nonisolated private final class Replies: @unchecked Sendable {
    private let lock = NSLock()
    private var queue: [Result<NsStatus, NsFailure>]

    init(_ queue: [Result<NsStatus, NsFailure>]) { self.queue = queue }

    func next() throws -> NsStatus {
        try lock.withLock { queue.removeFirst() }.get()
    }
}

@Test func aRefreshAdoptsWhatNsReports() async {
    let replies = Replies([.success(sampleStatus)])
    let ns = NsWorkspace { try replies.next() }

    await ns.refresh()

    #expect(ns.status == sampleStatus)
    #expect(ns.problem == nil)
    #expect(ns.place(of: URL(fileURLWithPath: "/dev/worktrees/NS-12/web")) == .branch("NS-12"))
}

@Test func aFailureKeepsTheLastStatusAndSaysWhy() async {
    let replies = Replies([.success(sampleStatus), .failure(NsFailure(message: "o ns rpc terminou"))])
    let ns = NsWorkspace { try replies.next() }

    await ns.refresh()
    await ns.refresh()

    #expect(ns.status == sampleStatus)
    #expect(ns.problem == "o ns rpc terminou")
}

@Test func withoutNsEverySessionIsElsewhere() async {
    let replies = Replies([.failure(NsFailure(message: "ns não encontrado no PATH"))])
    let ns = NsWorkspace { try replies.next() }

    await ns.refresh()

    #expect(ns.status == nil)
    #expect(ns.problem == "ns não encontrado no PATH")
    #expect(ns.place(of: URL(fileURLWithPath: "/dev/worktrees/NS-12")) == .elsewhere)
}

@Test func theNextSuccessClearsTheProblem() async {
    let replies = Replies([.failure(NsFailure(message: "o ns rpc terminou")), .success(sampleStatus)])
    let ns = NsWorkspace { try replies.next() }

    await ns.refresh()
    await ns.refresh()

    #expect(ns.problem == nil)
    #expect(ns.status == sampleStatus)
}
