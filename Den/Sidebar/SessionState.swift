enum SessionState: Comparable, CaseIterable {
    case awaitingDecision, outOfTokens, newReply, thinking

    var name: String {
        switch self {
        case .awaitingDecision: "Aguardando decisão"
        case .outOfTokens: "Tokens esgotados"
        case .newReply: "Resposta nova"
        case .thinking: "Pensando"
        }
    }

    func label(count: Int) -> String {
        switch self {
        case .newReply where count > 1: "\(count) respostas novas"
        default: "\(count) \(name.lowercased())"
        }
    }
}

struct PrevailingState: Equatable {
    let state: SessionState
    let count: Int

    init?(_ states: some Sequence<SessionState?>) {
        let present = states.compactMap(\.self)
        guard let state = present.min() else { return nil }
        self.state = state
        count = present.count { $0 == state }
    }

    var label: String { state.label(count: count) }
}

struct SessionTally: Equatable {
    let total: Int
    let prevailing: PrevailingState?
}

extension ChatModel {
    var sessionState: SessionState? {
        var states: [SessionState] = []
        if pending != nil || pendingQuestion != nil { states.append(.awaitingDecision) }
        if isRateLimited { states.append(.outOfTokens) }
        if hasUnread { states.append(.newReply) }
        if isBusy { states.append(.thinking) }
        return PrevailingState(states)?.state
    }
}
