import Foundation
import Observation

@MainActor
@Observable
final class NsWorkspace {
    private(set) var status: NsStatus?
    private(set) var problem: String?

    @ObservationIgnored private let fetch: @Sendable () async throws -> NsStatus

    init(fetch: @escaping @Sendable () async throws -> NsStatus) {
        self.fetch = fetch
    }

    static func live(_ environment: any AppEnvironment) -> NsWorkspace {
        let client = NsClient.locating(override: environment.nsOverride)
        return NsWorkspace { try await client.status() }
    }

    func place(of directory: URL) -> SessionPlace {
        status?.place(of: directory) ?? .elsewhere
    }

    func refresh() async {
        do {
            let latest = try await fetch()
            if latest != status { status = latest }
            problem = nil
        } catch let failure as NsFailure {
            problem = failure.message
        } catch is DecodingError {
            problem = "o ns rpc respondeu num formato inesperado"
        } catch {
            problem = "não consegui iniciar o ns rpc: \(error.localizedDescription)"
        }
    }

    func watch(every interval: Duration = .seconds(5)) async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: interval)
        }
    }
}
