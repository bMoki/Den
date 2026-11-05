import SwiftUI

struct ServiceDot: View {
    let state: ServiceState
    var isDatabase = false
    var size: CGFloat = 7

    @State private var dimmed = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: isDatabase ? 2 : size / 2, style: .continuous)
        Group {
            if state == .parado {
                shape.strokeBorder(Theme.textFaint, lineWidth: 1.5)
            } else {
                shape.fill(Self.color(state))
            }
        }
        .frame(width: size, height: size)
        .opacity(state == .iniciando && dimmed ? 0.35 : 1)
        .task(id: state) {
            dimmed = false
            guard state == .iniciando else { return }
            withAnimation(.easeInOut(duration: 0.55).repeatForever()) { dimmed = true }
        }
        .accessibilityHidden(true)
    }

    static func color(_ state: ServiceState) -> Color {
        switch state {
        case .parado: Theme.textTertiary
        case .iniciando: Theme.accent
        case .rodando: Theme.added
        case .falhou: Theme.removed
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
    static let remove = "Remover branch…"
}
