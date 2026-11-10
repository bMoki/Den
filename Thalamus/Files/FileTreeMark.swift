import Foundation

nonisolated enum FileTreeMark {
    static func letter(_ state: GitFileState) -> String {
        switch state {
        case .modified: "M"
        case .added: "A"
        case .untracked: "U"
        case .deleted: "D"
        case .renamed: "R"
        case .conflicted: "!"
        }
    }

    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "heic", "svg", "ico", "bmp", "tiff"]

    static func isImage(_ name: String) -> Bool {
        imageExtensions.contains((name as NSString).pathExtension.lowercased())
    }
}
