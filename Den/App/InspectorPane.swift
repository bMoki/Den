import Foundation

enum InspectorPane: String {
    case closed = ""
    case services
    case changes

    static let storageKey = "Den.inspector"

    func shown(inBranch: Bool) -> InspectorPane {
        self == .services && !inBranch ? .changes : self
    }

    static func opening(inBranch: Bool) -> InspectorPane {
        inBranch ? .services : .changes
    }
}
