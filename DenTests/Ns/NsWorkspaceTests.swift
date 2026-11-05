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
    let ns = NsWorkspace(fetch: { try replies.next() }, start: { branch, _, progress in
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

@Test func restartStopsThenStartsOnlyThatService() async {
    let replies = Replies([.success(sampleStatus)])
    let calls = Recorder()
    let ns = NsWorkspace(fetch: { try replies.next() },
                         start: { branch, service, _ in calls.append("start \(branch) \(service ?? "-")") },
                         stop: { branch, service, _ in calls.append("stop \(branch) \(service ?? "-")") })

    let running = Task { await ns.restart("NS-12", service: "backend") }
    while ns.activity["NS-12"] == nil, calls.all.isEmpty { await Task.yield() }
    await running.value

    #expect(calls.all == ["stop NS-12 backend", "start NS-12 backend"])
    #expect(ns.activity.isEmpty)
}

@Test func aServiceActionSaysWhichServiceIsBusy() async {
    let replies = Replies([.success(sampleStatus)])
    let gate = AsyncStream<Void>.makeStream()
    let ns = NsWorkspace(fetch: { try replies.next() }, stop: { _, _, _ in
        for await _ in gate.stream { break }
    })

    let running = Task { await ns.stop("NS-12", service: "frontend") }
    while ns.activity["NS-12"] == nil { await Task.yield() }
    #expect(ns.activity["NS-12"] == .init(kind: .stop, label: "Parando frontend..."))

    gate.continuation.yield()
    await running.value
}

@Test func aFailedStopIsReportedOnTheBranch() async {
    let replies = Replies([.success(sampleStatus), .success(sampleStatus)])
    let ns = NsWorkspace(fetch: { try replies.next() },
                         stop: { _, _, _ in throw NsFailure(message: "docker fora") })

    await ns.stop("NS-12")
    #expect(ns.actionProblems["NS-12"] == "docker fora")
    #expect(ns.activity.isEmpty)

    await ns.stop("NS-123")
    #expect(ns.actionProblems["NS-123"] == "docker fora")
}

@Test func updatingShowsTheResultOfEachRepo() async {
    let replies = Replies([.success(sampleStatus)])
    let repos = [
        RepoUpdate(repo: "frontend", branch: "master", status: .updated, commits: 3),
        RepoUpdate(repo: "manager", branch: "master", status: .conflict, conflicts: ["a.ts"]),
    ]
    let ns = NsWorkspace(fetch: { try replies.next() }, update: { branch, progress in
        #expect(branch == "NS-12")
        progress("Atualizando 2 repos com a branch principal...")
        return NsClient.Pulled(repos: repos)
    })

    await ns.update("NS-12")

    #expect(ns.updateReports == [.init(branch: "NS-12", repos: repos)])
    #expect(ns.activity.isEmpty)
    #expect(ns.status == sampleStatus)
}

@Test func anUpdateThatCannotRunIsReportedOnTheBranchWithoutADialog() async {
    let replies = Replies([.success(sampleStatus)])
    let ns = NsWorkspace(fetch: { try replies.next() },
                         update: { _, _ in throw NsFailure(message: "Branch 'NS-12' não encontrada") })

    await ns.update("NS-12")

    #expect(ns.updateReports.isEmpty)
    #expect(ns.actionProblems["NS-12"] == "Branch 'NS-12' não encontrada")
}

@Test func twoBranchesUpdatedAtOnceKeepBothReports() async {
    let replies = Replies([.success(sampleStatus), .success(sampleStatus)])
    let ns = NsWorkspace(fetch: { try replies.next() }, update: { branch, _ in
        NsClient.Pulled(repos: [RepoUpdate(repo: branch, status: .upToDate)])
    })

    async let first: Void = ns.update("NS-12")
    async let second: Void = ns.update("NS-13")
    _ = await (first, second)

    #expect(Set(ns.updateReports.map(\.branch)) == ["NS-12", "NS-13"])
    let shown = ns.updateReports.first?.branch
    ns.dismissUpdateReport()
    #expect(ns.updateReports.map(\.branch) == [shown == "NS-12" ? "NS-13" : "NS-12"])
}

private let cleanPreview = NsClient.RemovalPreview(volume: "ns_db_ns-12", uncommitted: [])

@Test func removingAsksWithThePreviewAndArchivesTheSessionsOfTheBranch() async {
    let gone = NsStatus(worktreesDir: "/dev/worktrees", baseRepos: [],
                        branches: [.init(branch: "NS-123", path: "/dev/worktrees/NS-123")])
    let replies = Replies([.success(sampleStatus), .success(gone)])
    let removed = Recorder()
    let ns = NsWorkspace(fetch: { try replies.next() },
                         previewRemoval: { _ in cleanPreview },
                         remove: { branch, purge, progress in
                             progress("Removendo worktrees...")
                             removed.append("\(branch) \(purge)")
                         })
    await ns.refresh()

    await ns.askToRemove("NS-12")
    #expect(ns.removal?.state == .ready(cleanPreview))
    await ns.remove("NS-12", purge: false)

    #expect(removed.all == ["NS-12 false"])
    #expect(ns.removal == nil)
    #expect(ns.activity.isEmpty)
    #expect(ns.removedBranch(of: URL(fileURLWithPath: "/dev/worktrees/NS-12/backend")) == "NS-12")
    #expect(ns.branchName(of: URL(fileURLWithPath: "/dev/worktrees/NS-12/backend")) == nil)
}

@Test func uncommittedChangesBlockTheRemoval() async {
    let preview = NsClient.RemovalPreview(volume: "v", uncommitted: [.init(repo: "backend", files: ["A.java"])])
    let removed = Recorder()
    let ns = NsWorkspace(fetch: { sampleStatus },
                         previewRemoval: { _ in preview },
                         remove: { branch, _, _ in removed.append(branch) })

    await ns.askToRemove("NS-12")
    await ns.remove("NS-12", purge: true)

    #expect(removed.all.isEmpty)
    #expect(ns.removal?.state == .ready(preview))
}

@Test func aPreviewThatFailsSaysWhyAndCannotRemove() async {
    let removed = Recorder()
    let ns = NsWorkspace(fetch: { sampleStatus },
                         previewRemoval: { _ in throw NsFailure(message: "Branch 'NS-12' não encontrada") },
                         remove: { branch, _, _ in removed.append(branch) })

    await ns.askToRemove("NS-12")
    await ns.remove("NS-12", purge: false)

    #expect(ns.removal?.state == .failed("Branch 'NS-12' não encontrada"))
    #expect(removed.all.isEmpty)
}

@Test func aPreviewArrivingAfterCancelDoesNotReopenTheDialog() async {
    let gate = AsyncStream<Void>.makeStream()
    let ns = NsWorkspace(fetch: { sampleStatus }, previewRemoval: { _ in
        for await _ in gate.stream { break }
        return cleanPreview
    })

    let asking = Task { await ns.askToRemove("NS-12") }
    while ns.removal == nil { await Task.yield() }
    ns.cancelRemoval()
    gate.continuation.yield()
    await asking.value

    #expect(ns.removal == nil)
}

@Test func theInspectorShowsServicesOnlyInABranch() {
    #expect(InspectorPane.services.shown(inBranch: true) == .services)
    #expect(InspectorPane.services.shown(inBranch: false) == .changes)
    #expect(InspectorPane.opening(inBranch: true) == .services)
    #expect(InspectorPane.opening(inBranch: false) == .changes)
}
