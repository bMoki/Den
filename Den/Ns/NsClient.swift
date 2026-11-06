import Foundation
import HarnessCore

nonisolated struct NsFailure: Error, Equatable, Sendable {
    let message: String
    var hint: String?
}

nonisolated struct NsQuestion: Decodable, Equatable, Sendable {
    let message: String
    let `default`: Bool
}

nonisolated struct RepoUpdate: Decodable, Equatable, Sendable {
    enum Status: String, Decodable, Sendable {
        case updated, upToDate = "up-to-date", skipped, failed, conflict
    }

    let repo: String
    var branch: String?
    let status: Status
    var message: String?
    var commits: Int?
    var conflicts: [String]?
}

nonisolated struct NsEvent: Decodable, Equatable, Sendable {
    let step: String
    let label: String
}

actor NsClient {
    typealias Locate = @Sendable () async throws -> ProcessTransport.Launch

    typealias Progress = @Sendable (String) -> Void
    typealias Steps = @Sendable (NsEvent) -> Void
    typealias Ask = @Sendable (NsQuestion) async -> Bool

    nonisolated struct Created: Decodable, Equatable, Sendable {
        nonisolated struct Paths: Decodable, Equatable, Sendable {
            let root: String
        }

        nonisolated struct MissingRepo: Decodable, Equatable, Sendable {
            let repo: String
            let message: String
        }

        let paths: Paths
        let missingRepos: [MissingRepo]
    }

    nonisolated struct Pulled: Decodable, Equatable, Sendable {
        let repos: [RepoUpdate]
    }

    nonisolated struct RemovalPreview: Decodable, Equatable, Sendable {
        nonisolated struct UncommittedRepo: Decodable, Equatable, Sendable {
            let repo: String
            let files: [String]
        }

        let volume: String
        let uncommitted: [UncommittedRepo]
    }

    nonisolated struct Snapshot: Decodable, Equatable, Sendable, Identifiable {
        let branch: String
        let name: String
        let ref: String
        let createdAt: String

        var id: String { ref }

        var created: Date? {
            try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(createdAt)
        }

        var age: String? {
            created?.formatted(.relative(presentation: .named).locale(Locale(identifier: "pt_BR")))
        }
    }

    nonisolated struct SnapshotGroup: Decodable, Equatable, Sendable {
        let branch: String
        let orphan: Bool
        let snapshots: [Snapshot]

        init(branch: String, orphan: Bool, snapshots: [Snapshot]) {
            self.branch = branch
            self.orphan = orphan
            self.snapshots = snapshots
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            branch = try container.decode(String.self, forKey: .branch)
            orphan = try container.decodeIfPresent(Bool.self, forKey: .orphan) ?? false
            snapshots = try container.decode([Snapshot].self, forKey: .snapshots)
        }

        private enum CodingKeys: String, CodingKey { case branch, orphan, snapshots }
    }

    private nonisolated struct Request<Input: Encodable>: Encodable {
        let type = "op"
        let id: String
        let op: String
        let input: Input
    }

    private nonisolated struct NoInput: Encodable {}

    private nonisolated struct StopInput: Encodable {
        let branch: String
        let service: String?
    }

    private nonisolated struct StartInput: Encodable {
        let branch: String
        let service: String?
        let installMissingDeps = "always"
    }

    nonisolated struct NewBranch: Encodable, Equatable, Sendable {
        let branch: String
        let repos: [String]
        let nickname: String?
        let installMissingDeps = "ask"
    }

    private nonisolated struct AddRepoInput: Encodable {
        let branch: String
        let repo: String
    }

    private nonisolated struct BranchInput: Encodable {
        let branch: String
    }

    private nonisolated struct SnapshotInput: Encodable {
        let branch: String
        let name: String
    }

    private nonisolated struct TakeSnapshotInput: Encodable {
        let branch: String
        let name: String
        let replace: Bool
    }

    private nonisolated struct RestoreInput: Encodable {
        let branch: String
        let ref: String
    }

    private nonisolated struct RemoveInput: Encodable {
        let branch: String
        let purge: Bool
    }

    private nonisolated struct PrepareInput: Encodable {
        let branch: String
        let installMissingDeps = "ask"
    }

    private nonisolated struct Answer: Encodable {
        let type = "answer"
        let id: String
        let ask: String
        let value: Bool
    }

    private nonisolated struct Ignored: Decodable {}

    private nonisolated struct Header: Decodable {
        nonisolated struct Body: Decodable {
            let message: String
            let hint: String?
        }

        let type: String
        let id: String?
        let error: Body?
        let event: NsEvent?
        let ask: String?
        let question: NsQuestion?
    }

    private nonisolated struct Reply<Value: Decodable>: Decodable {
        let result: Value
    }

    private let locate: Locate
    private let timeout: Duration
    private var transport: ProcessTransport?
    private var connecting: Task<ProcessTransport, any Error>?
    private var pending: [String: CheckedContinuation<Data, any Error>] = [:]
    private var deadlines: [String: Task<Void, Never>] = [:]
    private var timeouts: [String: Duration] = [:]
    private var steps: [String: Steps] = [:]
    private var asks: [String: Ask] = [:]
    private var nextID = 0

    init(timeout: Duration = .seconds(30), locate: @escaping Locate) {
        self.timeout = timeout
        self.locate = locate
    }

    func status() async throws -> NsStatus {
        try await call("status", input: NoInput())
    }

    func start(branch: String, service: String? = nil, progress: @escaping Progress) async throws {
        let _: Ignored = try await call("start", input: StartInput(branch: branch, service: service),
                                        timeout: .seconds(900), progress: progress)
    }

    func stop(branch: String, service: String? = nil, progress: @escaping Progress) async throws {
        let _: Ignored = try await call("stop", input: StopInput(branch: branch, service: service),
                                        timeout: .seconds(120), progress: progress)
    }

    func new(_ request: NewBranch, steps: @escaping Steps, ask: @escaping Ask) async throws -> Created {
        try await call("new", input: request,
                       timeout: .seconds(1800), steps: steps, ask: ask)
    }

    func addRepo(branch: String, repo: String, steps: @escaping Steps) async throws {
        let _: Ignored = try await call("addRepo", input: AddRepoInput(branch: branch, repo: repo),
                                        timeout: .seconds(600), steps: steps)
    }

    func prepare(branch: String, steps: @escaping Steps, ask: @escaping Ask) async throws {
        let _: Ignored = try await call("prepare", input: PrepareInput(branch: branch),
                                        timeout: .seconds(900), steps: steps, ask: ask)
    }

    func pull(branch: String, progress: @escaping Progress) async throws -> Pulled {
        try await call("pull", input: BranchInput(branch: branch), timeout: .seconds(600), progress: progress)
    }

    func removalPreview(branch: String) async throws -> RemovalPreview {
        try await call("rmPreview", input: BranchInput(branch: branch), timeout: .seconds(60))
    }

    func remove(branch: String, purge: Bool, progress: @escaping Progress) async throws {
        let _: Ignored = try await call("rm", input: RemoveInput(branch: branch, purge: purge),
                                        timeout: .seconds(600), progress: progress)
    }

    func openDatabase(branch: String) async throws {
        let _: Ignored = try await call("dbOpen", input: BranchInput(branch: branch), timeout: .seconds(60))
    }

    func snapshots() async throws -> [SnapshotGroup] {
        try await call("dbSnapshots", input: NoInput(), timeout: .seconds(60))
    }

    func takeSnapshot(branch: String, name: String, replace: Bool, progress: @escaping Progress) async throws {
        let _: Ignored = try await call("dbSnapshot", input: TakeSnapshotInput(branch: branch, name: name, replace: replace),
                                        timeout: .seconds(900), progress: progress)
    }

    func restore(branch: String, ref: String, progress: @escaping Progress) async throws {
        let _: Ignored = try await call("dbRestore", input: RestoreInput(branch: branch, ref: ref),
                                        timeout: .seconds(900), progress: progress)
    }

    func removeSnapshot(branch: String, name: String) async throws {
        let _: Ignored = try await call("dbRmSnapshot", input: SnapshotInput(branch: branch, name: name),
                                        timeout: .seconds(120))
    }

    private func call<Value: Decodable>(_ op: String, input: some Encodable, timeout: Duration? = nil,
                                        progress: @escaping Progress) async throws -> Value {
        try await call(op, input: input, timeout: timeout, steps: { progress($0.label) })
    }

    private func call<Value: Decodable>(_ op: String, input: some Encodable,
                                        timeout: Duration? = nil,
                                        steps: Steps? = nil, ask: Ask? = nil) async throws -> Value {
        let transport = try await connected()
        nextID += 1
        let id = String(nextID)
        let request = try JSONEncoder().encode(Request(id: id, op: op, input: input))
        let timeout = timeout ?? self.timeout
        let line = try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            self.steps[id] = steps
            asks[id] = ask
            timeouts[id] = timeout
            try? transport.writeSync(request)
            arm(id, on: transport)
        }
        return try JSONDecoder().decode(Reply<Value>.self, from: line).result
    }

    private func arm(_ id: String, on transport: ProcessTransport) {
        guard let timeout = timeouts[id] else { return }
        deadlines[id] = Task {
            guard (try? await Task.sleep(for: timeout)) != nil else { return }
            await self.expire(id, on: transport)
        }
    }

    private func connected() async throws -> ProcessTransport {
        if let transport { return transport }
        if let connecting { return try await connecting.value }
        let task = Task {
            let launch = try await locate()
            let transport = ProcessTransport()
            let lines = try await transport.start(launch)
            self.transport = transport
            Task { await self.read(lines, from: transport) }
            return transport
        }
        connecting = task
        defer { connecting = nil }
        return try await task.value
    }

    private func read(_ lines: AsyncThrowingStream<Data, any Error>, from source: ProcessTransport) async {
        var reason = "o ns rpc terminou"
        do {
            for try await line in lines { receive(line) }
        } catch let failure as ProcessTransport.ExitFailure {
            reason = Self.reason(failure)
        } catch {
            reason = "o ns rpc enviou uma resposta ilegível"
        }
        guard transport === source else { return }
        transport = nil
        for id in pending.keys { finish(id, with: .failure(NsFailure(message: reason))) }
    }

    private func receive(_ line: Data) {
        guard let header = try? JSONDecoder().decode(Header.self, from: line), let id = header.id else { return }
        switch header.type {
        case "result": finish(id, with: .success(line))
        case "error":
            finish(id, with: .failure(NsFailure(message: header.error?.message ?? "erro no ns",
                                                hint: header.error?.hint)))
        case "event": if let event = header.event { steps[id]?(event) }
        case "ask": if let ask = header.ask, let question = header.question { reply(to: question, ask: ask, of: id) }
        default: break
        }
    }

    private func reply(to question: NsQuestion, ask: String, of id: String) {
        let asker = asks[id]
        deadlines.removeValue(forKey: id)?.cancel()
        Task {
            let value = await asker?(question) ?? question.default
            answer(Answer(id: id, ask: ask, value: value))
        }
    }

    private func answer(_ answer: Answer) {
        guard pending[answer.id] != nil, let transport, let line = try? JSONEncoder().encode(answer) else { return }
        try? transport.writeSync(line)
        arm(answer.id, on: transport)
    }

    private func expire(_ id: String, on stuck: ProcessTransport) async {
        guard pending[id] != nil else { return }
        finish(id, with: .failure(NsFailure(message: "o ns rpc não respondeu a tempo")))
        guard transport === stuck, pending.isEmpty else { return }
        transport = nil
        await stuck.terminate()
    }

    private func finish(_ id: String, with result: Result<Data, any Error>) {
        deadlines.removeValue(forKey: id)?.cancel()
        timeouts.removeValue(forKey: id)
        steps.removeValue(forKey: id)
        asks.removeValue(forKey: id)
        pending.removeValue(forKey: id)?.resume(with: result)
    }

    private static func reason(_ failure: ProcessTransport.ExitFailure) -> String {
        let line = failure.standardError
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last { !$0.isEmpty }
        return line.map { "o ns rpc saiu: \($0)" } ?? "o ns rpc saiu com código \(failure.status)"
    }
}

extension NsClient {
    nonisolated static let pathKey = "Den.nsPath"

    static func locating(override: String?, shell: ShellEnvironment = .shared) -> NsClient {
        NsClient {
            let variables = await shell.resolve().variables
            let candidates = override.map { [$0] }
                ?? (variables["PATH"] ?? "").split(separator: ":").map { "\($0)/ns" }
            guard let executable = candidates.first(where: FileManager.default.isExecutableFile(atPath:))
            else { throw NsFailure(message: "ns não encontrado no PATH") }
            return ProcessTransport.Launch(executable: executable, arguments: ["rpc"],
                                           workingDirectory: URL(fileURLWithPath: NSHomeDirectory()),
                                           environment: variables)
        }
    }
}

extension NsClient {
    private nonisolated struct NicknameInput: Encodable {
        let branch: String
        let nickname: String
    }

    func setNickname(branch: String, nickname: String) async throws {
        let _: Ignored = try await call("setNickname", input: NicknameInput(branch: branch, nickname: nickname),
                                        timeout: .seconds(30))
    }
}
