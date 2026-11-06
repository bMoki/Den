import Foundation
import HarnessCore

struct ComposerHistory {
    private(set) var position: Int?
    private(set) var draft = ""
    private var messages: [String] = []

    var isBrowsing: Bool { position != nil }

    func canGoOlder(in sent: [String]) -> Bool {
        position.map { $0 > 0 } ?? !sent.isEmpty
    }

    mutating func older(in sent: [String], current: String) -> String? {
        let browsed = isBrowsing ? messages : sent
        let next = (position ?? browsed.count) - 1
        guard browsed.indices.contains(next) else { return nil }
        if !isBrowsing {
            messages = sent
            draft = current
        }
        position = next
        return messages[next]
    }

    mutating func newer() -> String? {
        guard let position else { return nil }
        let next = position + 1
        guard messages.indices.contains(next) else {
            defer { leave() }
            return draft
        }
        self.position = next
        return messages[next]
    }

    mutating func leave() {
        position = nil
        draft = ""
        messages = []
    }
}

struct QueuedMessage {
    let turnID: UUID
    let lineID: UUID
    let entry: TranscriptEntry
    let attachments: [PendingAttachment]
    var isReported = false
    var isWithdrawing = false

    var text: String {
        if case .userMessage(let text, _) = entry.kind { text } else { "" }
    }
}

struct ComposerState {
    var history = ComposerHistory()
    var queue: [QueuedMessage] = []
}
