import Foundation
import HarnessCore

nonisolated struct SessionOpenings: StoredInDefaults, Equatable, Sendable {
    static let key = "Den.sessionOpenings"

    var openedAt: [UUID: Date] = [:]

    mutating func note(_ id: UUID, at moment: Date = .now) {
        openedAt[id] = moment
    }

    mutating func forget(_ id: UUID) {
        openedAt[id] = nil
    }

    func lastOpened(among sessions: [SessionSummary]) -> UUID? {
        sessions.max { lhs, rhs in
            (openedAt[lhs.id] ?? .distantPast, lhs.updatedAt) < (openedAt[rhs.id] ?? .distantPast, rhs.updatedAt)
        }?.id
    }
}
