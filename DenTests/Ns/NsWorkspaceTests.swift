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

@Test func openingTheDatabaseAsksNsForThatBranch() async {
    let replies = Replies([.success(sampleStatus)])
    let opened = Recorder()
    let ns = NsWorkspace(fetch: { try replies.next() }, openDatabase: { opened.append($0) })

    await ns.openDatabase("NS-12")

    #expect(opened.all == ["NS-12"])
    #expect(ns.actionProblems["NS-12"] == nil)
    #expect(ns.activity.isEmpty)
}

@Test func aDatabaseAppNotConfiguredShowsHowToConfigureIt() async {
    let replies = Replies([.success(sampleStatus)])
    let ns = NsWorkspace(fetch: { try replies.next() },
                         openDatabase: { _ in
                             throw NsFailure(message: "Nenhum app de banco configurado no ns.",
                                             hint: "Rode 'ns config set databaseApp datagrip'.")
                         })

    await ns.openDatabase("NS-12")

    #expect(ns.actionProblems["NS-12"] == "Nenhum app de banco configurado no ns. Rode 'ns config set databaseApp datagrip'.")
    #expect(ns.activity.isEmpty)
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

nonisolated private let cleanPreview = NsClient.RemovalPreview(volume: "ns_db_ns-12", uncommitted: [])

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
    #expect(InspectorPane.services.shown(inBranch: false) == .files)
    #expect(InspectorPane.opening(inBranch: true) == .services)
    #expect(InspectorPane.opening(inBranch: false) == .files)
}

private func snapshot(_ branch: String, _ name: String) -> NsClient.Snapshot {
    NsClient.Snapshot(branch: branch, name: name, ref: "\(branch):\(name)", createdAt: "2026-11-05T10:00:00.000Z")
}

private func snapshotOperations(_ groups: [NsClient.SnapshotGroup], calls: Recorder = Recorder()) -> NsWorkspace.SnapshotOperations {
    NsWorkspace.SnapshotOperations(list: { calls.append("list"); return groups },
                                   take: { branch, name, replace, _ in calls.append("take \(branch) \(name)\(replace ? " replace" : "")") },
                                   restore: { branch, ref, _ in calls.append("restore \(branch) \(ref)") },
                                   remove: { branch, name in calls.append("remove \(branch) \(name)") })
}

@Test func restoreListsThisBranchFirstThenTheMainBranchThenTheRestThenTheOrphans() async {
    let groups = [
        NsClient.SnapshotGroup(branch: "NS-0", orphan: true, snapshots: [snapshot("NS-0", "velho")]),
        NsClient.SnapshotGroup(branch: "NS-7", orphan: false, snapshots: [snapshot("NS-7", "a")]),
        NsClient.SnapshotGroup(branch: "master", orphan: false, snapshots: [snapshot("master", "seed")]),
        NsClient.SnapshotGroup(branch: "NS-9", orphan: false, snapshots: []),
        NsClient.SnapshotGroup(branch: "NS-12", orphan: false, snapshots: [snapshot("NS-12", "antes")]),
        NsClient.SnapshotGroup(branch: "NS-3", orphan: false, snapshots: [snapshot("NS-3", "b")]),
    ]
    let ns = NsWorkspace(fetch: { sampleStatus }, snapshots: snapshotOperations(groups))

    await ns.loadSnapshots()

    #expect(ns.restoreSources(for: "NS-12").map(\.branch) == ["NS-12", "master", "NS-7", "NS-3", "NS-0"])
    #expect(ns.snapshots(of: "NS-12").map(\.name) == ["antes"])
    #expect(ns.snapshots(of: "NS-9").isEmpty)
}

@Test func restoringFromItsOwnBranchOrAnotherSendsTheFullReference() async {
    let calls = Recorder()
    let ns = NsWorkspace(fetch: { sampleStatus }, snapshots: snapshotOperations([], calls: calls))

    await ns.restore("NS-12", from: "NS-12:antes")
    await ns.restore("NS-12", from: "master:seed")

    #expect(calls.all == ["restore NS-12 NS-12:antes", "restore NS-12 master:seed"])
    #expect(ns.actionProblems["NS-12"] == nil)
    #expect(ns.activity.isEmpty)
}

@Test func takingAndRemovingASnapshotReloadTheList() async {
    let calls = Recorder()
    let ns = NsWorkspace(fetch: { sampleStatus }, snapshots: snapshotOperations([], calls: calls))

    await ns.takeSnapshot("NS-12", name: "antes")
    await ns.takeSnapshot("NS-12", name: "antes", replacing: true)
    await ns.removeSnapshot(snapshot("NS-12", "antes"))

    #expect(calls.all == ["take NS-12 antes", "list", "take NS-12 antes replace", "list", "remove NS-12 antes", "list"])
}

@Test func snapshotsThatCannotBeListedSayWhy() async {
    let ns = NsWorkspace(fetch: { sampleStatus })

    await ns.loadSnapshots()

    #expect(ns.snapshotGroups.isEmpty)
    #expect(ns.snapshotsProblem == "ns indisponível")
}

@Test func aNicknameShowsAtOnceAndIsSavedInNs() async {
    let saved = Recorder()
    let gate = AsyncStream<Void>.makeStream()
    var named = sampleStatus
    named.branches[0].nickname = "Agenda recorrente"
    let replies = Replies([.success(sampleStatus), .success(named)])
    let ns = NsWorkspace(fetch: { try replies.next() }, setNickname: { branch, nickname in
        saved.append("\(branch) \(nickname)")
        for await _ in gate.stream { break }
    })
    await ns.refresh()

    let renaming = Task { await ns.setNickname("NS-12", to: "  Agenda recorrente ") }
    while saved.all.isEmpty { await Task.yield() }
    #expect(ns.branch(named: "NS-12")?.nickname == "Agenda recorrente")

    gate.continuation.yield()
    await renaming.value
    #expect(saved.all == ["NS-12 Agenda recorrente"])
    #expect(ns.actionProblems["NS-12"] == nil)
}

@Test func clearingANicknameSendsAnEmptyText() async {
    let saved = Recorder()
    var named = sampleStatus
    named.branches[0].nickname = "Agenda"
    let replies = Replies([.success(named), .success(sampleStatus)])
    let ns = NsWorkspace(fetch: { try replies.next() }, setNickname: { saved.append("\($0) [\($1)]") })
    await ns.refresh()

    await ns.setNickname("NS-12", to: "   ")

    #expect(saved.all == ["NS-12 []"])
    #expect(ns.branch(named: "NS-12")?.nickname == nil)
}

@Test func aRefreshWhileSavingKeepsTheNewNickname() async {
    let gate = AsyncStream<Void>.makeStream()
    let saving = Recorder()
    let ns = NsWorkspace(fetch: { sampleStatus }, setNickname: { _, _ in
        saving.append("saving")
        for await _ in gate.stream { break }
    })
    await ns.refresh()

    let naming = Task { await ns.setNickname("NS-12", to: "Agenda") }
    while saving.all.isEmpty { await Task.yield() }
    await ns.refresh()
    #expect(ns.branch(named: "NS-12")?.nickname == "Agenda")

    gate.continuation.yield()
    await naming.value
}

@Test func anUnchangedNicknameIsNotSaved() async {
    let saved = Recorder()
    let ns = NsWorkspace(fetch: { sampleStatus }, setNickname: { saved.append($0 + $1) })
    await ns.refresh()

    await ns.setNickname("NS-12", to: "")

    #expect(saved.all.isEmpty)
}

@Test func aNicknameNsRefusesIsReportedAndNsDecides() async {
    let replies = Replies([.success(sampleStatus), .success(sampleStatus)])
    let ns = NsWorkspace(fetch: { try replies.next() },
                         setNickname: { _, _ in throw NsFailure(message: "Branch 'NS-12' não encontrada") })
    await ns.refresh()

    await ns.setNickname("NS-12", to: "Agenda")

    #expect(ns.actionProblems["NS-12"] == "Branch 'NS-12' não encontrada")
    #expect(ns.branch(named: "NS-12")?.nickname == nil)
}
