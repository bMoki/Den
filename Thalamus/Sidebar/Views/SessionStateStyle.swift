import SwiftUI

extension SessionState {
    var color: Color {
        switch self {
        case .awaitingDecision: Theme.alertText
        case .outOfTokens: Theme.removed
        case .newReply: Theme.added
        case .thinking: Theme.accent
        }
    }
}
