import Foundation
import Testing
@testable import Den

nonisolated private let created = NsClient.Created(paths: .init(root: "/w/NS-1"), missingRepos: [])

private func operations(
    create: @escaping @Sendable (String, [String], @escaping NsClient.Steps,
                                 @escaping NsClient.Ask) async throws -> NsClient.Created = { _, _, _, _ in created },
    addRepo: @escaping @Sendable (String, String, @escaping NsClient.Steps) async throws -> Void = { _, _, _ in },
    prepare: @escaping @Sendable (String, @escaping NsClient.Steps,
                                  @escaping NsClient.Ask) async throws -> Void = { _, _, _ in }
) -> BranchCreation.Operations {
    BranchCreation.Operations(create: create, addRepo: addRepo, prepare: prepare)
}

@MainActor
@Test func theFormAsksOnlyForANameAndStartsWithManager() {
    let creation = BranchCreation(operations: operations())

    #expect(creation.repos == [.manager])
    #expect(creation.name.isEmpty)
    #expect(!creation.canCreate)
    creation.name = "NS 1"
    #expect(!creation.canCreate)
    creation.name = " NS-1 "
    #expect(creation.canCreate)
}

@MainActor
@Test func creatingSendsTheReposAndOpensTheSessionAtTheRoot() async {
    let calls = Recorder()
    let creation = BranchCreation(operations: operations(create: { branch, repos, steps, _ in
        calls.append("\(branch) \(repos.joined(separator: ","))")
        steps(NsEvent(step: "new:repo", label: "Configurando Backend..."))
        steps(NsEvent(step: "database:start", label: "Iniciando PostgreSQL..."))
        return created
    }))
    creation.name = "NS-1"
    creation.repos = [.manager, .parents]

    var opened: URL?
    await creation.create { opened = $0 }

    #expect(calls.all == ["NS-1 manager,parents"])
    #expect(opened == URL(fileURLWithPath: "/w/NS-1", isDirectory: true))
    #expect(creation.phase == .finished)
    #expect(creation.steps.map(\.id) == ["create", "add:parents", "database", "aliases", "deps"])
    #expect(creation.steps.allSatisfy { $0.state == .done })
    #expect(!creation.isPresented)
}

@MainActor
@Test func eachStepOfTheNsLightsUpItsRow() async {
    let gate = AsyncStream<Void>.makeStream()
    let creation = BranchCreation(operations: operations(create: { _, _, steps, _ in
        steps(NsEvent(step: "new:seed", label: "Seedando volume do banco..."))
        steps(NsEvent(step: "portless:aliases", label: "Registrando aliases Portless..."))
        for await _ in gate.stream { break }
        return created
    }))
    creation.name = "NS-1"

    let running = Task { await creation.create { _ in } }
    while creation.steps.first(where: { $0.id == "aliases" })?.state != .running { await Task.yield() }

    #expect(creation.steps.map(\.state) == [.done, .done, .running, .waiting])
    #expect(creation.steps[2].detail == "Registrando aliases Portless...")
    #expect(creation.isRunning)

    gate.continuation.yield()
    await running.value
}

@MainActor
@Test func aQuestionFromTheNsWaitsForTheAnswerAndReopensTheDialog() async {
    let answers = Recorder()
    let creation = BranchCreation(operations: operations(create: { _, _, _, ask in
        let value = await ask(NsQuestion(message: "Instalar dependências agora?", default: true))
        answers.append(String(value))
        return created
    }))
    creation.name = "NS-1"

    let running = Task { await creation.create { _ in } }
    creation.isPresented = false
    while creation.question == nil { await Task.yield() }

    #expect(creation.question?.message == "Instalar dependências agora?")
    #expect(creation.isPresented)
    creation.reply(false)
    await running.value

    #expect(answers.all == ["false"])
    #expect(creation.question == nil)
}

@MainActor
@Test func aMissingRepoKeepsTheBranchAndCanBeRetriedAlone() async {
    let calls = Recorder()
    let creation = BranchCreation(operations: operations(
        create: { _, _, _, _ in
            NsClient.Created(paths: .init(root: "/w/NS-1"),
                             missingRepos: [.init(repo: "report-server", message: "fatal: could not read")])
        },
        addRepo: { branch, repo, _ in calls.append("add \(branch) \(repo)") },
        prepare: { branch, _, _ in calls.append("prepare \(branch)") }))
    creation.name = "NS-1"
    creation.repos = [.manager, .reportServer]

    var opened: URL?
    await creation.create { opened = $0 }

    #expect(opened != nil)
    #expect(creation.isPresented)
    #expect(creation.missing == [.init(repo: "report-server", message: "fatal: could not read")])
    #expect(creation.steps.first { $0.id == "add:report-server" }?.state == .failed)

    await creation.retry("report-server")

    #expect(calls.all == ["add NS-1 report-server", "prepare NS-1"])
    #expect(creation.missing.isEmpty)
    #expect(creation.steps.first { $0.id == "add:report-server" }?.state == .done)
}

@MainActor
@Test func aRetryThatFailsAgainShowsTheNewError() async {
    let creation = BranchCreation(operations: operations(
        create: { _, _, _, _ in
            NsClient.Created(paths: .init(root: "/w/NS-1"), missingRepos: [.init(repo: "parents", message: "x")])
        },
        addRepo: { _, _, _ in throw NsFailure(message: "Branch base 'origin/main' não existe no parents") }))
    creation.name = "NS-1"
    creation.repos = [.parents]
    await creation.create { _ in }

    await creation.retry("parents")

    #expect(creation.missing == [.init(repo: "parents", message: "Branch base 'origin/main' não existe no parents")])
    #expect(creation.steps.first { $0.id == "add:parents" }?.state == .failed)
}

@MainActor
@Test func aFailureStopsTheCreationOnTheRunningRow() async {
    let failure = NsFailure(message: "docker parado", hint: "A branch foi criada. Para preparar de novo: ns prepare NS-1")
    let creation = BranchCreation(operations: operations(create: { _, _, steps, _ in
        steps(NsEvent(step: "database:start", label: "Iniciando PostgreSQL..."))
        throw failure
    }))
    creation.name = "NS-1"

    var opened = false
    await creation.create { _ in opened = true }

    #expect(!opened)
    #expect(creation.phase == .failed(failure))
    #expect(creation.steps.first { $0.id == "database" }?.state == .failed)
    #expect(creation.isPresented)
    #expect(!creation.isRunning)
}

@Test func theNsStepsGroupIntoTheDialogRows() {
    #expect(BranchCreation.stepID(of: "new:validate") == "create")
    #expect(BranchCreation.stepID(of: "new:repo") == "create")
    #expect(BranchCreation.stepID(of: "new:add:report-server") == "add:report-server")
    #expect(BranchCreation.stepID(of: "database:wait") == "database")
    #expect(BranchCreation.stepID(of: "portless:proxy") == "aliases")
    #expect(BranchCreation.stepID(of: "prepare:deps:frontend:done") == "deps")
}

@MainActor
@Test func plusBranchReturnsToTheCreationInProgress() async {
    let gate = AsyncStream<Void>.makeStream()
    let ns = NsWorkspace(fetch: { throw NsFailure(message: "x") },
                         create: operations(create: { _, _, _, _ in
                             for await _ in gate.stream { break }
                             return created
                         }))
    ns.newBranch()
    let first = ns.creation
    first?.name = "NS-1"
    let running = Task { await first?.create { _ in } }
    while first?.isRunning != true { await Task.yield() }
    first?.isPresented = false

    ns.newBranch()
    #expect(ns.creation === first)
    #expect(first?.isPresented == true)

    gate.continuation.yield()
    await running.value
    ns.newBranch()
    #expect(ns.creation !== first)
}

@MainActor
@Test func aFailureWithAQuestionOpenTakesItsDefaultAndRefreshes() async {
    let refreshes = Recorder()
    let answers = Recorder()
    let answered = AsyncStream<Void>.makeStream()
    let creation = BranchCreation(operations: operations(create: { _, _, _, ask in
        Task {
            answers.append(String(await ask(NsQuestion(message: "?", default: true))))
            answered.continuation.yield()
        }
        try await Task.sleep(for: .milliseconds(100))
        throw NsFailure(message: "docker parado")
    }), refreshed: { refreshes.append("refresh") })
    creation.name = "NS-1"

    await creation.create { _ in }
    for await _ in answered.stream { break }

    #expect(creation.question == nil)
    #expect(answers.all == ["true"])
    #expect(refreshes.all == ["refresh"])
}

@MainActor
@Test func aRetryWhosePrepareFailsKeepsTheRepoIncluded() async {
    let refreshes = Recorder()
    let creation = BranchCreation(operations: operations(
        create: { _, _, _, _ in
            NsClient.Created(paths: .init(root: "/w/NS-1"), missingRepos: [.init(repo: "parents", message: "x")])
        },
        addRepo: { _, _, steps in steps(NsEvent(step: "add:parents:worktree", label: "Criando worktree...")) },
        prepare: { _, _, _ in throw NsFailure(message: "docker parado") }),
        refreshed: { refreshes.append("refresh") })
    creation.name = "NS-1"
    creation.repos = [.parents]
    await creation.create { _ in }

    await creation.retry("parents")

    #expect(creation.missing.isEmpty)
    #expect(creation.steps.first { $0.id == "add:parents" }?.state == .done)
    #expect(creation.phase == .notPrepared(repo: "parents", NsFailure(message: "docker parado")))
    #expect(refreshes.all == ["refresh", "refresh"])
}
