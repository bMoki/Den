import Foundation
import HarnessCore

nonisolated struct NsFailure: Error, Equatable, Sendable {
    let message: String
}

actor NsClient {
    typealias Locate = @Sendable () async throws -> ProcessTransport.Launch

    private nonisolated struct Request: Encodable {
        let type = "op"
        let id: String
        let op: String
    }

    private nonisolated struct Header: Decodable {
        nonisolated struct Body: Decodable {
            let message: String
        }

        let type: String
        let id: String?
        let error: Body?
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
    private var nextID = 0

    init(timeout: Duration = .seconds(30), locate: @escaping Locate) {
        self.timeout = timeout
        self.locate = locate
    }

    func status() async throws -> NsStatus {
        try await call("status")
    }

    private func call<Value: Decodable>(_ op: String) async throws -> Value {
        let transport = try await connected()
        nextID += 1
        let id = String(nextID)
        let request = try JSONEncoder().encode(Request(id: id, op: op))
        let line = try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            try? transport.writeSync(request)
            deadlines[id] = Task { [timeout] in
                guard (try? await Task.sleep(for: timeout)) != nil else { return }
                await self.expire(id, on: transport)
            }
        }
        return try JSONDecoder().decode(Reply<Value>.self, from: line).result
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
        case "error": finish(id, with: .failure(NsFailure(message: header.error?.message ?? "erro no ns")))
        default: break
        }
    }

    private func expire(_ id: String, on stuck: ProcessTransport) async {
        guard pending[id] != nil else { return }
        finish(id, with: .failure(NsFailure(message: "o ns rpc não respondeu a tempo")))
        guard transport === stuck else { return }
        transport = nil
        await stuck.terminate()
    }

    private func finish(_ id: String, with result: Result<Data, any Error>) {
        deadlines.removeValue(forKey: id)?.cancel()
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
