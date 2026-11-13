import SwiftUI

extension PullRequestTone {
    var color: Color {
        switch self {
        case .failure: Theme.removed
        case .attention: Theme.modified
        case .open: Theme.added
        case .draft, .closed: Theme.textTertiary
        case .merged: Theme.accent
        }
    }

    var fill: Color { color.opacity(0.14) }

    var symbol: Icon {
        self == .merged ? .merged : .pullRequest
    }
}
