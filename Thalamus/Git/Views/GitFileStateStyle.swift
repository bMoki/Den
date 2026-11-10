import SwiftUI

extension GitFileState {
    var color: Color {
        switch self {
        case .modified: Theme.modified
        case .added, .untracked: Theme.added
        case .deleted: Theme.removed
        case .renamed: Theme.renamed
        case .conflicted: Theme.accent
        }
    }

    var accessibilityName: String {
        switch self {
        case .modified: "Modificado"
        case .added: "Adicionado"
        case .deleted: "Apagado"
        case .renamed: "Renomeado"
        case .untracked: "Não rastreado"
        case .conflicted: "Em conflito"
        }
    }
}
