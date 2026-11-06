import Darwin
import Foundation

enum NsConfigFolder {
    nonisolated static let key = "Den.nsConfigDir"
    nonisolated static let variable = "NS_CONFIG_DIR"

    static func export(_ folder: String?,
                       set: (String, String) -> Void = { setenv($0, $1, 1) }) {
        guard let folder else { return }
        set(variable, (folder as NSString).expandingTildeInPath)
    }

    nonisolated static func passedOn(_ environment: [String: String]) -> [String] {
        environment[variable].map { ["\(variable)=\($0)"] } ?? []
    }
}
