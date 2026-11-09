import Foundation
import Observation

@MainActor
@Observable
final class BranchDependencies {
    nonisolated struct Operations: Sendable {
        var load: @Sendable (_ branch: String) async throws -> [NsClient.RepoDependencies]
        var install: @Sendable (_ branch: String, _ repo: String) async throws -> NsClient.RepoDependencies

        static let unavailable: Operations = {
            let failure = NsFailure(message: "ns indisponível")
            return Operations(load: { _ in throw failure }, install: { _, _ in throw failure })
        }()
    }

    struct Row: Identifiable, Equatable {
        var repo: NsClient.RepoDependencies
        var isInstalling = false
        var failure: String?

        var id: String { repo.id }
    }

    private(set) var rows: [String: [Row]] = [:]
    private(set) var problems: [String: String] = [:]

    @ObservationIgnored private let operations: Operations

    init(operations: Operations = .unavailable) {
        self.operations = operations
    }

    func rows(of branch: String) -> [Row] {
        rows[branch] ?? []
    }

    func isShown(for branch: String) -> Bool {
        rows[branch]?.isEmpty == false || problems[branch] != nil
    }

    func isInstalling(in branch: String) -> Bool {
        rows(of: branch).contains(where: \.isInstalling)
    }

    func load(_ branch: String) async {
        let load = operations.load
        do {
            let loaded = try await load(branch)
            let current = rows(of: branch)
            rows[branch] = loaded.map { repo in
                var row = current.first { $0.id == repo.id } ?? Row(repo: repo)
                row.repo = repo
                if !repo.state.needsInstall { row.failure = nil }
                return row
            }
            problems[branch] = nil
        } catch {
            problems[branch] = Self.describe(error)
        }
    }

    func reload(_ branch: String) async {
        guard isShown(for: branch) else { return }
        await load(branch)
    }

    func install(_ repo: String, in branch: String) async {
        guard let row = rows(of: branch).first(where: { $0.id == repo }), !row.isInstalling else { return }
        update(repo, in: branch) { $0.isInstalling = true; $0.failure = nil }
        let install = operations.install
        let result: Result<NsClient.RepoDependencies, any Error>
        do {
            result = .success(try await install(branch, repo))
        } catch {
            result = .failure(error)
        }
        update(repo, in: branch) { row in
            row.isInstalling = false
            switch result {
            case .success(let installed): row.repo = installed
            case .failure(let error): row.failure = Self.describe(error)
            }
        }
    }

    private func update(_ repo: String, in branch: String, _ change: (inout Row) -> Void) {
        guard var list = rows[branch], let index = list.firstIndex(where: { $0.id == repo }) else { return }
        change(&list[index])
        rows[branch] = list
    }

    private static func describe(_ error: any Error) -> String {
        (error as? NsFailure)?.detail ?? error.localizedDescription
    }
}
