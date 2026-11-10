import Foundation

extension ChatModel {
    func attach(imageData: Data) {
        pendingAttachments.append(PendingAttachment(data: imageData, mediaType: "image/png"))
    }

    func attach(fileData: Data, name: String, mediaType: String) {
        pendingAttachments.append(
            PendingAttachment(data: fileData, mediaType: mediaType, name: name))
    }

    func removeAttachment(_ id: UUID) {
        pendingAttachments.removeAll { $0.id == id }
    }

    @discardableResult
    func capturePaste(_ text: String) -> Bool {
        guard LongText.isLong(text) else { return false }
        pendingPastes.append(PastedText(text: text))
        return true
    }

    func removePaste(_ id: UUID) {
        pendingPastes.removeAll { $0.id == id }
    }

    func expandPaste(_ id: UUID) {
        guard let index = pendingPastes.firstIndex(where: { $0.id == id }) else { return }
        let text = pendingPastes.remove(at: index).text
        if prompt.isEmpty || prompt.last?.isNewline == true {
            prompt += text
        } else {
            prompt += "\n" + text
        }
    }

    var sentMessages: [String] {
        lines.filter { $0.role == .user && !$0.isQueued && !$0.text.isEmpty }.map(\.text)
    }

    var isBrowsingHistory: Bool { composer.history.isBrowsing }

    var canRecallOlder: Bool {
        (!isBrowsingHistory && composer.queue.contains(where: \.isReported))
            || composer.history.canGoOlder(in: sentMessages)
    }

    func recallOlder() async {
        guard !composer.queue.contains(where: \.isWithdrawing) else { return }
        if !isBrowsingHistory, let queued = composer.queue.last(where: \.isReported),
           await withdrawQueued(queued.turnID) {
            return
        }
        if let text = composer.history.older(in: sentMessages, current: prompt) { prompt = text }
    }

    func recallNewer() {
        if let text = composer.history.newer() { prompt = text }
    }

    func takeSuggestion() {
        guard let reply = visibleSuggestion else { return }
        prompt = reply
    }
}
