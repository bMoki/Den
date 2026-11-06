import Foundation

nonisolated enum BranchNickname {
    static let maxLength = 40

    static func normalized(_ text: String) -> String? {
        let line = text.split(whereSeparator: \.isNewline).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return line.isEmpty ? nil : String(line.prefix(maxLength))
    }

    static func matches(_ nickname: String?, _ search: String) -> Bool {
        nickname?.range(of: search, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}
