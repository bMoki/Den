import Foundation

enum InspectorPane: String {
    case closed = ""
    case services
    case files
    case changes

    static let storageKey = PreferenceKey.named("inspector")

    func shown(inBranch: Bool) -> InspectorPane {
        self == .services && !inBranch ? .files : self
    }

    static func opening(inBranch: Bool) -> InspectorPane {
        inBranch ? .services : .files
    }
}
