import SwiftUI

extension GitFileState {
    var color: Color {
        switch self {
        case .modified: Theme.palette.fileStates.modified
        case .added, .untracked: Theme.palette.fileStates.added
        case .deleted: Theme.palette.fileStates.deleted
        case .renamed: Theme.palette.fileStates.renamed
        case .conflicted: Theme.palette.fileStates.conflicted
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
