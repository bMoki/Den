import Foundation

nonisolated protocol StoredInDefaults: Codable {
    static var key: String { get }
    init()
}

nonisolated extension StoredInDefaults {
    init(defaults: UserDefaults?) {
        self = defaults?.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(Self.self, from: $0) } ?? Self()
    }

    func save(to defaults: UserDefaults?) {
        guard let data = try? JSONEncoder().encode(self) else { return }
        defaults?.set(data, forKey: Self.key)
    }
}
