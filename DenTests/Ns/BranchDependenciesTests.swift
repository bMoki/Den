import Foundation
import Testing
@testable import Den

nonisolated private func repo(_ id: String, _ state: NsClient.RepoDependencies.State) -> NsClient.RepoDependencies {
    NsClient.RepoDependencies(id: id, cwd: "/w/NS-1/\(id)", state: state, command: "npm install")
}

@Test func loadingShowsEachRepoAndWhichNeedInstalling() async {
    let dependencies = BranchDependencies(operations: .init(
        load: { _ in [repo("frontend", .reused), repo("manager", .divergent), repo("report-server", .missing)] },
        install: { _, _ in repo("x", .installed) }))

    await dependencies.load("NS-1")

    #expect(dependencies.rows(of: "NS-1").map(\.id) == ["frontend", "manager", "report-server"])
    #expect(dependencies.rows(of: "NS-1").map(\.repo.state.needsInstall) == [false, true, true])
    #expect(dependencies.rows(of: "NS-2").isEmpty)
}

@Test func installingTakesTheNewState() async {
    let calls = Recorder()
    let dependencies = BranchDependencies(operations: .init(
        load: { _ in [repo("manager", .divergent)] },
        install: { branch, id in
            calls.append("install \(branch) \(id)")
            return repo(id, .installed)
        }))
    await dependencies.load("NS-1")

    await dependencies.install("manager", in: "NS-1")

    #expect(calls.all == ["install NS-1 manager"])
    #expect(dependencies.rows(of: "NS-1").first?.repo.state == .installed)
    #expect(dependencies.rows(of: "NS-1").first?.isInstalling == false)
    #expect(!dependencies.isInstalling(in: "NS-1"))
}

@Test func aFailedInstallShowsTheErrorUntilItSucceeds() async {
    let attempts = Recorder()
    let dependencies = BranchDependencies(operations: .init(
        load: { _ in [repo("report-server", .missing)] },
        install: { _, id in
            attempts.append(id)
            if attempts.all.count == 1 {
                throw NsFailure(message: "Falha ao instalar", hint: "Rode manualmente: bun install")
            }
            return repo(id, .installed)
        }))
    await dependencies.load("NS-1")

    await dependencies.install("report-server", in: "NS-1")
    let failed = dependencies.rows(of: "NS-1").first
    await dependencies.install("report-server", in: "NS-1")

    #expect(failed?.failure == "Falha ao instalar\nRode manualmente: bun install")
    #expect(failed?.repo.state == .missing)
    #expect(dependencies.rows(of: "NS-1").first?.failure == nil)
    #expect(dependencies.rows(of: "NS-1").first?.repo.state == .installed)
}

@Test func aFailureKeepsTheErrorAcrossAReloadWhileStillMissing() async {
    let dependencies = BranchDependencies(operations: .init(
        load: { _ in [repo("manager", .missing)] },
        install: { _, _ in throw NsFailure(message: "ETIMEDOUT") }))
    await dependencies.load("NS-1")
    await dependencies.install("manager", in: "NS-1")

    await dependencies.load("NS-1")

    #expect(dependencies.rows(of: "NS-1").first?.failure == "ETIMEDOUT")
}

@Test func reloadingOnlyChecksBranchesAlreadyShown() async {
    let loads = Recorder()
    let dependencies = BranchDependencies(operations: .init(
        load: { branch in
            loads.append(branch)
            return [repo("frontend", .installed)]
        },
        install: { _, _ in repo("x", .installed) }))

    await dependencies.reload("NS-1")
    await dependencies.load("NS-2")
    await dependencies.reload("NS-2")

    #expect(loads.all == ["NS-2", "NS-2"])
}

@Test func aLoadFailureIsShownInsteadOfTheRows() async {
    let dependencies = BranchDependencies(operations: .unavailable)

    await dependencies.load("NS-1")
    await dependencies.install("frontend", in: "NS-1")

    #expect(dependencies.problems["NS-1"] == "ns indisponível")
    #expect(dependencies.rows(of: "NS-1").isEmpty)
}

@Test func startingABranchChecksItsDependenciesAgain() async {
    let loads = Recorder()
    let ns = NsWorkspace(fetch: { sampleStatus }, start: { _, _, _ in },
                         dependencies: .init(load: { branch in
                             loads.append(branch)
                             return [repo("frontend", .installed)]
                         }, install: { _, _ in repo("x", .installed) }))
    await ns.dependencies.load("NS-12")

    await ns.start("NS-12")
    await ns.start("NS-13")

    #expect(loads.all == ["NS-12", "NS-12"])
}

@Test func aBranchWaitsForItsInstallBeforeStarting() async {
    let calls = Recorder()
    let gate = AsyncStream<Void>.makeStream()
    let ns = NsWorkspace(fetch: { sampleStatus }, start: { branch, _, _ in calls.append("start \(branch)") },
                         dependencies: .init(load: { _ in [repo("manager", .missing)] },
                                             install: { _, id in
                                                 for await _ in gate.stream { break }
                                                 return repo(id, .installed)
                                             }))
    await ns.dependencies.load("NS-12")

    let installing = Task { await ns.dependencies.install("manager", in: "NS-12") }
    while !ns.dependencies.isInstalling(in: "NS-12") { await Task.yield() }
    await ns.start("NS-12")
    gate.continuation.yield()
    await installing.value
    await ns.start("NS-12")

    #expect(calls.all == ["start NS-12"])
}
