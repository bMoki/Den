import Foundation
import Observation

@MainActor
@Observable
final class BranchCreation {
    nonisolated struct Operations: Sendable {
        var create: @Sendable (_ request: NsClient.NewBranch, _ steps: @escaping NsClient.Steps,
                               _ ask: @escaping NsClient.Ask) async throws -> NsClient.Created
        var addRepo: @Sendable (_ branch: String, _ repo: String,
                                _ steps: @escaping NsClient.Steps) async throws -> Void
        var prepare: @Sendable (_ branch: String, _ steps: @escaping NsClient.Steps,
                                _ ask: @escaping NsClient.Ask) async throws -> Void

        static let unavailable: Operations = {
            let failure = NsFailure(message: "ns indisponível")
            return Operations(create: { _, _, _ in throw failure },
                              addRepo: { _, _, _ in throw failure },
                              prepare: { _, _, _ in throw failure })
        }()
    }

    enum Repo: String, CaseIterable, Identifiable {
        case manager, reportServer = "report-server", parents

        static let fixed = ["backend", "frontend", "docs"]

        var id: String { rawValue }
    }

    enum Phase: Equatable {
        case form, running, finished
        case failed(NsFailure)
        case notPrepared(repo: String, NsFailure)
    }

    struct Step: Identifiable, Equatable {
        enum State { case waiting, running, done, failed }

        let id: String
        let title: String
        var state = State.waiting
        var detail: String?
    }

    struct MissingRepo: Identifiable, Equatable {
        let repo: String
        var message: String
        var retrying = false

        var id: String { repo }
    }

    var name = ""
    var nickname = ""
    var repos: Set<Repo> = [.manager]
    var isPresented = true
    private(set) var phase = Phase.form
    private(set) var steps: [Step] = []
    private(set) var question: NsQuestion?
    private(set) var missing: [MissingRepo] = []
    private(set) var adding: Repo?

    @ObservationIgnored private let operations: Operations
    @ObservationIgnored private let refreshed: @MainActor (_ branch: String) async -> Void
    @ObservationIgnored private var pendingAnswer: CheckedContinuation<Bool, Never>?

    init(operations: Operations, refreshed: @escaping @MainActor (_ branch: String) async -> Void = { _ in }) {
        self.operations = operations
        self.refreshed = refreshed
    }

    var isRunning: Bool {
        phase == .running || missing.contains(where: \.retrying)
    }

    var canCreate: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return phase == .form && !trimmed.isEmpty && !trimmed.contains(where: \.isWhitespace)
    }

    func create(opened: @escaping @MainActor (URL) async -> Void) async {
        guard canCreate else { return }
        name = name.trimmingCharacters(in: .whitespaces)
        let (operations, ask) = (operations, asker())
        let chosen = Repo.allCases.filter(repos.contains)
        let request = NsClient.NewBranch(branch: name, repos: chosen.map(\.rawValue),
                                         nickname: BranchNickname.normalized(nickname))
        steps = [Step(id: StepID.create, title: Self.createTitle(withManager: chosen.contains(.manager)))]
            + chosen.filter { $0 != .manager }.map { Self.including($0.rawValue) }
            + Self.preparing
        phase = .running
        let advance: (NsEvent) -> Void = { self.advance(to: $0) }
        let result = await following(advance) { steps in
            try await operations.create(request, steps, ask)
        }
        settleQuestion()
        switch result {
        case .success(let created):
            finishSteps()
            missing = created.missingRepos.map { MissingRepo(repo: $0.repo, message: $0.message) }
            for repo in missing { mark(StepID.add(repo.repo), .failed) }
            phase = .finished
            if missing.isEmpty { isPresented = false }
            await refreshed(name)
            await opened(URL(fileURLWithPath: created.paths.root, isDirectory: true))
        case .failure(let error):
            if let index = steps.firstIndex(where: { $0.state == .running }) { steps[index].state = .failed }
            phase = .failed(Self.failure(error))
            isPresented = true
            await refreshed(name)
        }
    }

    func add(_ repo: Repo, to branch: String) async {
        name = branch
        adding = repo
        steps = [Self.including(repo.rawValue)] + Self.preparing
        phase = .running
        await include(repo.rawValue)
    }

    func retry(_ repo: String) async {
        guard let index = missing.firstIndex(where: { $0.repo == repo }), !missing[index].retrying else { return }
        missing[index].retrying = true
        if adding != nil { phase = .running }
        await include(repo)
    }

    func prepareAgain() async {
        guard case .notPrepared(let repo, _) = phase else { return }
        phase = .running
        await prepare(after: repo)
    }

    private func include(_ repo: String) async {
        let row = StepID.add(repo)
        mark(row, .running)
        let (branch, operations) = (name, operations)
        let show: (NsEvent) -> Void = { self.describe(row, with: $0) }
        let added = await following(show) { try await operations.addRepo(branch, repo, $0) }
        describe(row, with: nil)
        if case .failure(let error) = added {
            mark(row, .failed)
            let message = Self.failure(error).message
            if missing.contains(where: { $0.repo == repo }) {
                update(repo) { $0.message = message; $0.retrying = false }
            } else {
                missing.append(MissingRepo(repo: repo, message: message))
            }
            if phase == .running { phase = .finished }
            return
        }
        missing.removeAll { $0.repo == repo }
        mark(row, .done)
        await prepare(after: repo)
    }

    private func prepare(after repo: String) async {
        let (branch, operations, ask) = (name, operations, asker())
        let row = StepID.add(repo)
        let show: (NsEvent) -> Void = { event in
            if self.phase == .running { self.advance(to: event) } else { self.describe(row, with: event) }
        }
        let prepared = await following(show) { try await operations.prepare(branch, $0, ask) }
        settleQuestion()
        describe(row, with: nil)
        if case .failure(let error) = prepared {
            if phase == .running, let index = steps.firstIndex(where: { $0.state == .running }) {
                steps[index].state = .failed
            }
            phase = .notPrepared(repo: repo, Self.failure(error))
        } else {
            if phase == .running { finishSteps() }
            phase = .finished
            if adding != nil { isPresented = false }
        }
        await refreshed(name)
    }

    func reply(_ value: Bool) {
        question = nil
        pendingAnswer?.resume(returning: value)
        pendingAnswer = nil
    }

    private func following<Value>(_ apply: @escaping (NsEvent) -> Void,
                                  _ operation: (@escaping NsClient.Steps) async throws -> Value) async
        -> Result<Value, any Error> {
        let (events, sink) = AsyncStream<NsEvent>.makeStream()
        let applying = Task { @MainActor in
            for await event in events { apply(event) }
        }
        let result: Result<Value, any Error>
        do {
            result = .success(try await operation { sink.yield($0) })
        } catch {
            result = .failure(error)
        }
        sink.finish()
        await applying.value
        return result
    }

    private func asker() -> NsClient.Ask {
        { @MainActor [weak self] question in
            guard let self else { return question.default }
            return await withCheckedContinuation { continuation in
                self.settleQuestion()
                self.pendingAnswer = continuation
                self.question = question
                self.isPresented = true
            }
        }
    }

    private func settleQuestion() {
        guard let question else { return }
        reply(question.default)
    }

    private func advance(to event: NsEvent) {
        guard phase == .running, let index = steps.firstIndex(where: { $0.id == Self.stepID(of: event.step) })
        else { return }
        for earlier in steps.indices where earlier < index && steps[earlier].state != .failed {
            steps[earlier].state = .done
            steps[earlier].detail = nil
        }
        steps[index].state = .running
        steps[index].detail = event.label
    }

    private func describe(_ id: String, with event: NsEvent?) {
        if let index = steps.firstIndex(where: { $0.id == id }) { steps[index].detail = event?.label }
    }

    private func finishSteps() {
        for index in steps.indices where steps[index].state != .failed {
            steps[index].state = .done
            steps[index].detail = nil
        }
    }

    private func mark(_ id: String, _ state: Step.State) {
        if let index = steps.firstIndex(where: { $0.id == id }) { steps[index].state = state }
    }

    private func update(_ repo: String, _ change: (inout MissingRepo) -> Void) {
        if let index = missing.firstIndex(where: { $0.repo == repo }) { change(&missing[index]) }
    }

    private enum StepID {
        static let create = "create"
        static let database = "database"
        static let aliases = "aliases"
        static let deps = "deps"

        static func add(_ repo: String) -> String { "add:\(repo)" }
    }

    static func stepID(of step: String) -> String {
        if step.hasPrefix("new:add:") { return StepID.add(String(step.dropFirst("new:add:".count))) }
        if step.hasPrefix("new:") { return StepID.create }
        if step.hasPrefix("database:") { return StepID.database }
        if step.hasPrefix("portless:") { return StepID.aliases }
        if step.hasPrefix("prepare:deps") { return StepID.deps }
        return step
    }

    private static func including(_ repo: String) -> Step {
        Step(id: StepID.add(repo), title: "Incluir \(repo)")
    }

    private static let preparing = [Step(id: StepID.database, title: "Subir o banco da branch"),
                                    Step(id: StepID.aliases, title: "Criar aliases"),
                                    Step(id: StepID.deps, title: "Instalar dependências")]

    private static func createTitle(withManager: Bool) -> String {
        let repos = Repo.fixed + (withManager ? [Repo.manager.rawValue] : [])
        return "Criar a branch em \(repos.dropLast().joined(separator: ", ")) e \(repos.last ?? "")"
    }

    private static func failure(_ error: any Error) -> NsFailure {
        error as? NsFailure ?? NsFailure(message: error.localizedDescription)
    }
}
