import Foundation

struct FileNameRequest: Identifiable {
    enum Kind { case newFile, newFolder, rename(FileNode) }

    let kind: Kind
    let folder: URL
    let id = UUID()

    var title: String {
        switch kind {
        case .newFile: "Novo arquivo"
        case .newFolder: "Nova pasta"
        case .rename: "Renomear"
        }
    }

    var initialName: String {
        if case .rename(let node) = kind { node.name } else { "" }
    }

    var current: URL? {
        if case .rename(let node) = kind { node.url } else { nil }
    }
}
