import Foundation
import Observation

@MainActor
@Observable
final class NsWorkspace {
    typealias BranchAction = @Sendable (_ branch: String, _ service: String?,
                                        _ progress: @escaping NsClient.Progress) async throws -> Void

    struct Activity: Equatable {
        enum Kind { case start, stop, restart }

        var kind: Kind
        var label: String
    }

    private(set) var status: NsStatus?
    private(set) var problem: String?
    private(set) var activity: [String: Activity] = [:]
    private(set) var actionProblems: [String: String] = [:]

    @ObservationIgnored private let fetch: @Sendable () async throws -> NsStatus
    @ObservationIgnored private let startBranch: BranchAction
    @ObservationIgnored private let stopBranch: BranchAction

    init(fetch: @escaping @Sendable () async throws -> NsStatus,
         start: @escaping BranchAction = { _, _, _ in },
         stop: @escaping BranchAction = { _, _, _ in }) {
        self.fetch = fetch
        startBranch = start
        stopBranch = stop
    }

    static func live(_ environment: any AppEnvironment) -> NsWorkspace {
        let client = NsClient.locating(override: environment.nsOverride)
        return NsWorkspace(fetch: { try await client.status() },
                           start: { try await client.start(branch: $0, service: $1, progress: $2) },
                           stop: { try await client.stop(branch: $0, service: $1, progress: $2) })
    }

    func place(of directory: URL) -> SessionPlace {
        status?.place(of: directory) ?? .elsewhere
    }

    func branch(named name: String) -> NsStatus.Branch? {
        status?.branch(named: name)
    }

    func branchName(of directory: URL) -> String? {
        if case .branch(let name) = place(of: directory) { name } else { nil }
    }

    func refresh() async {
        do {
            let latest = try await fetch()
            if latest != status { status = latest }
            problem = nil
        } catch {
            problem = Self.describe(error)
        }
    }

    func start(_ branch: String, service: String? = nil) async {
        let start = startBranch
        await run(Activity(kind: .start, label: Self.label("Iniciando", service)), on: branch) {
            try await start(branch, service, $0)
        }
    }

    func stop(_ branch: String, service: String? = nil) async {
        let stop = stopBranch
        await run(Activity(kind: .stop, label: Self.label("Parando", service)), on: branch) {
            try await stop(branch, service, $0)
        }
    }

    func restart(_ branch: String, service: String) async {
        let (stop, start) = (stopBranch, startBranch)
        await run(Activity(kind: .restart, label: Self.label("Reiniciando", service)), on: branch) {
            try await stop(branch, service, $0)
            try await start(branch, service, $0)
        }
    }

    func watch(every interval: Duration = .seconds(5), whileBusy busyInterval: Duration = .seconds(1.5)) async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: isBusy ? busyInterval : interval)
        }
    }

    private var isBusy: Bool {
        !activity.isEmpty || status?.branches.contains { $0.services.contains { $0.state == .iniciando } } == true
    }

    private func run(_ started: Activity, on branch: String,
                     action: @Sendable (@escaping NsClient.Progress) async throws -> Void) async {
        guard activity[branch] == nil else { return }
        activity[branch] = started
        actionProblems[branch] = nil
        let (labels, sink) = AsyncStream<String>.makeStream()
        let follow = Task { @MainActor [weak self] in
            for await label in labels { self?.activity[branch]?.label = label }
        }
        do {
            try await action { sink.yield($0) }
        } catch let failure as NsFailure {
            actionProblems[branch] = failure.message
        } catch {
            actionProblems[branch] = error.localizedDescription
        }
        sink.finish()
        await follow.value
        activity[branch] = nil
        await refresh()
    }

    private static func label(_ verb: String, _ service: String?) -> String {
        service.map { "\(verb) \($0)..." } ?? "\(verb)..."
    }

    private static func describe(_ error: any Error) -> String {
        switch error {
        case let failure as NsFailure: failure.message
        case is DecodingError: "o ns rpc respondeu num formato inesperado"
        default: "não consegui iniciar o ns rpc: \(error.localizedDescription)"
        }
    }
}
