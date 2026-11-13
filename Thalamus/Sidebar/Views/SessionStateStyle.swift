import SwiftUI

extension SessionState {
    var color: Color {
        switch self {
        case .awaitingDecision: Theme.palette.sessionStates.awaitingDecision
        case .outOfTokens: Theme.palette.sessionStates.outOfTokens
        case .newReply: Theme.palette.sessionStates.newReply
        case .thinking: Theme.palette.sessionStates.thinking
        }
    }
}
