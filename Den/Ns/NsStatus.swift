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
        var session: String?
        var error: String?
    }

    nonisolated struct Repo: Decodable, Equatable, Sendable {
        var repo: String
        var gitBranch: String?
    }

    nonisolated struct Branch: Decodable, Equatable, Sendable {
        var branch: String
        var nickname: String?
        var path: String
        var services: [Service]
        var database: ServiceState
        var databasePort: Int?
        var repos: [Repo]?

        init(branch: String, nickname: String? = nil, path: String, services: [Service] = [],
             database: ServiceState = .parado, databasePort: Int? = nil, repos: [Repo]? = nil) {
            self.branch = branch
            self.nickname = nickname
            self.path = path
            self.services = services
            self.database = database
            self.databasePort = databasePort
            self.repos = repos
        }

        func gitBranch(of repo: String) -> String? {
            guard let repos else { return branch }
            return repos.first { $0.repo == repo }?.gitBranch
        }

        private enum CodingKeys: String, CodingKey {
            case branch, nickname, path, services, ports, sessions, errors, repos
        }

        private enum Key: String, CodingKey, CaseIterable {
            case db, backend, frontend, manager, reportServer

            var id: String { self == .reportServer ? "report-server" : rawValue }
        }

        static let serviceIDs = Key.allCases.filter { $0 != .db }.map(\.id)

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            branch = try container.decode(String.self, forKey: .branch)
            nickname = try? container.decodeIfPresent(String.self, forKey: .nickname)
            path = try container.decode(String.self, forKey: .path)
            repos = container.contains(.repos) ? (try? container.decode([Repo].self, forKey: .repos)) ?? [] : nil
            let states = try? container.nestedContainer(keyedBy: Key.self, forKey: .services)
            let ports = try? container.nestedContainer(keyedBy: Key.self, forKey: .ports)
            let sessions = try? container.nestedContainer(keyedBy: Key.self, forKey: .sessions)
            let errors = try? container.nestedContainer(keyedBy: Key.self, forKey: .errors)
            let state = { (key: Key) in try? states?.decodeIfPresent(ServiceState.self, forKey: key) }
            let port = { (key: Key) in try? ports?.decodeIfPresent(Int.self, forKey: key) }
            let session = { (key: Key) in try? sessions?.decodeIfPresent(String.self, forKey: key) }
            let error = { (key: Key) in try? errors?.decodeIfPresent(String.self, forKey: key) }
            database = state(.db) ?? .parado
            databasePort = port(.db)
            services = Key.allCases.dropFirst().compactMap { key in
                state(key).map {
                    Service(id: key.id, state: $0, port: port(key),
                            session: session(key), error: error(key))
                }
            }
        }
    }

    var worktreesDir: String?
    var baseRepos: [BaseRepo]
    var branches: [Branch]

    func branch(named name: String) -> Branch? {
        branches.first { $0.branch == name }
    }

    func place(of directory: URL, worktreesDir fallback: String? = nil) -> SessionPlace {
        let path = FolderPath.canonical(directory.path)
        if let branch = branches.first(where: { FolderPath.path(path, isInside: $0.path) }) {
            return .branch(branch.branch)
        }
        if let base = baseRepos.first(where: { FolderPath.path(path, isInside: $0.path) }) {
            return .baseRepo(base.repo)
        }
        if let worktreesDir = worktreesDir ?? fallback, let removed = Self.removedBranch(at: path, under: worktreesDir) {
            return .archived(removed)
        }
        return .elsewhere
    }

    private static func removedBranch(at path: String, under folder: String) -> String? {
        let root = FolderPath.canonical(folder)
        guard path.hasPrefix(root + "/") else { return nil }
        var branch = root
        for component in path.dropFirst(root.count + 1).split(separator: "/") {
            branch += "/" + component
            if !FileManager.default.fileExists(atPath: branch) {
                return String(branch.dropFirst(root.count + 1))
            }
        }
        return nil
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
    case archived(String)
    case elsewhere
}
