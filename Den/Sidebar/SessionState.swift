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
}

extension ChatModel {
    var sessionState: SessionState? {
        var states: [SessionState] = []
        if pending != nil || pendingQuestion != nil { states.append(.awaitingDecision) }
        if isRateLimited { states.append(.outOfTokens) }
        if hasUnread { states.append(.newReply) }
        if isBusy { states.append(.thinking) }
        return states.min()
    }
}
