import SwiftUI

struct ServiceDot: View {
    let state: ServiceState
    var isDatabase = false
    var size: Style.Size = .s7

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: isDatabase ? Theme.radius(.r2) : Theme.size(size) / 2, style: .continuous)
        Group {
            if state == .parado {
                shape.strokeBorder(Theme.palette.serviceStates.stoppedMark, lineWidth: Theme.line(.medium))
            } else {
                shape.fill(Self.color(state))
            }
        }
        .frame(width: Theme.size(size), height: Theme.size(size))
        .pulsing(state == .iniciando)
        .accessibilityHidden(true)
    }

    static func color(_ state: ServiceState) -> Color {
        switch state {
        case .parado: Theme.palette.serviceStates.stoppedText
        case .iniciando: Theme.palette.serviceStates.starting
        case .rodando: Theme.palette.serviceStates.running
        case .falhou: Theme.palette.serviceStates.failed
        }
    }
}

extension NsStatus.Branch {
    var stateSummary: String {
        (services.map { "\($0.id) \($0.state.label)" } + ["banco \(database.label)"]).joined(separator: ", ")
    }
}

enum BranchActionTitle {
    static let start = "Iniciar todos os Serviços"
    static let stop = "Parar todos os Serviços"
    static let update = "Atualizar com a branch principal"
    static let addRepo = "Adicionar repo"
    static let remove = "Remover branch…"
    static let openDatabase = "Abrir no app de banco"
    static let nickname = "Apelidar…"
}
