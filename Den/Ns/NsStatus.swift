import Foundation

nonisolated struct NsStatus: Decodable, Equatable, Sendable {
    nonisolated struct BaseRepo: Decodable, Equatable, Sendable {
        var repo: String
        var path: String
    }

    nonisolated struct Service: Equatable, Sendable, Identifiable {
        var id: String
        var state: ServiceState
        var port: Int?
    }

    nonisolated struct Branch: Decodable, Equatable, Sendable {
        var branch: String
        var path: String
        var services: [Service]
        var database: ServiceState
        var databasePort: Int?

        init(branch: String, path: String, services: [Service] = [],
             database: ServiceState = .parado, databasePort: Int? = nil) {
            self.branch = branch
            self.path = path
            self.services = services
            self.database = database
            self.databasePort = databasePort
        }

        private enum CodingKeys: String, CodingKey {
            case branch, path, services, ports
        }

        private enum Key: String, CodingKey, CaseIterable {
            case db, backend, frontend, manager, reportServer

            var id: String { self == .reportServer ? "report-server" : rawValue }
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            branch = try container.decode(String.self, forKey: .branch)
            path = try container.decode(String.self, forKey: .path)
            let states = try? container.nestedContainer(keyedBy: Key.self, forKey: .services)
            let ports = try? container.nestedContainer(keyedBy: Key.self, forKey: .ports)
            let state = { (key: Key) in try? states?.decodeIfPresent(ServiceState.self, forKey: key) }
            let port = { (key: Key) in try? ports?.decodeIfPresent(Int.self, forKey: key) }
            database = state(.db) ?? .parado
            databasePort = port(.db)
            services = Key.allCases.dropFirst().compactMap { key in
                state(key).map { Service(id: key.id, state: $0, port: port(key)) }
            }
        }
    }

    var baseRepos: [BaseRepo]
    var branches: [Branch]

    func branch(named name: String) -> Branch? {
        branches.first { $0.branch == name }
    }

    func place(of directory: URL) -> SessionPlace {
        let path = directory.standardizedFileURL.path
        if let branch = branches.first(where: { Self.path(path, isInside: $0.path) }) {
            return .branch(branch.branch)
        }
        if let base = baseRepos.first(where: { Self.path(path, isInside: $0.path) }) {
            return .baseRepo(base.repo)
        }
        return .elsewhere
    }

    private static func path(_ path: String, isInside folder: String) -> Bool {
        let root = URL(fileURLWithPath: folder).standardizedFileURL.path
        return path == root || path.hasPrefix(root + "/")
    }
}

nonisolated enum ServiceState: String, Decodable, Sendable {
    case parado, iniciando, rodando, falhou

    var label: String {
        switch self {
        case .parado: "Parado"
        case .iniciando: "Iniciando"
        case .rodando: "Rodando"
        case .falhou: "Falhou"
        }
    }
}

nonisolated enum SessionPlace: Hashable, Sendable {
    case branch(String)
    case baseRepo(String)
    case elsewhere
}
