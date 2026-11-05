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

@Test func startShowsEachStepThenRefreshes() async {
    let replies = Replies([.success(sampleStatus)])
    let gate = AsyncStream<Void>.makeStream()
    let ns = NsWorkspace(fetch: { try replies.next() }, start: { branch, progress in
        #expect(branch == "NS-12")
        progress("Iniciando Backend...")
        for await _ in gate.stream { break }
    })

    let running = Task { await ns.start("NS-12") }
    while ns.activity["NS-12"]?.label != "Iniciando Backend..." { await Task.yield() }
    #expect(ns.activity["NS-12"]?.kind == .start)

    gate.continuation.yield()
    await running.value
    #expect(ns.activity["NS-12"] == nil)
    #expect(ns.status == sampleStatus)
}

@Test func aFailedStopIsReportedOnTheBranch() async {
    let replies = Replies([.success(sampleStatus), .success(sampleStatus)])
    let ns = NsWorkspace(fetch: { try replies.next() },
                         stop: { _, _ in throw NsFailure(message: "docker fora") })

    await ns.stop("NS-12")
    #expect(ns.actionProblems["NS-12"] == "docker fora")
    #expect(ns.activity.isEmpty)

    await ns.stop("NS-123")
    #expect(ns.actionProblems["NS-123"] == "docker fora")
}

@Test func theInspectorShowsServicesOnlyInABranch() {
    #expect(InspectorPane.services.shown(inBranch: true) == .services)
    #expect(InspectorPane.services.shown(inBranch: false) == .changes)
    #expect(InspectorPane.opening(inBranch: true) == .services)
    #expect(InspectorPane.opening(inBranch: false) == .changes)
}
