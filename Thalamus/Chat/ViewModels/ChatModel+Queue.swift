import Foundation
import HarnessCore

extension ChatModel {
    func receive(_ update: SessionUpdate) {
        switch update {
        case .event(.messageQueue(let turnID, let state)):
            track(turnID, state)
        case .ended:
            settleQueue()
            apply(update)
        default:
            apply(update)
        }
    }

    func post(_ entry: TranscriptEntry, as turnID: UUID, attachments: [PendingAttachment]) {
        render(entry, persist: !isBusy)
        guard isBusy, let line = lines.last else { return }
        composer.queue.append(QueuedMessage(turnID: turnID, lineID: line.id, entry: entry,
                                            attachments: attachments))
    }

    func withdrawQueued(_ turnID: UUID) async -> Bool {
        guard let index = composer.queue.firstIndex(where: { $0.turnID == turnID }) else { return false }
        composer.queue[index].isWithdrawing = true
        let withdrawn = await session?.withdraw(turnID) ?? false
        guard let queued = takeQueued(turnID) else { return true }
        if withdrawn {
            restore(queued)
        } else {
            release(queued)
        }
        return withdrawn
    }

    func releaseUnreported() {
        for queued in composer.queue where !queued.isReported && !queued.isWithdrawing {
            if let taken = takeQueued(queued.turnID) { release(taken) }
        }
    }

    func settleQueue() {
        for queued in composer.queue {
            guard let taken = takeQueued(queued.turnID) else { continue }
            if taken.isReported {
                restore(taken)
            } else {
                release(taken)
            }
        }
    }

    func restoreQueued(_ turnID: UUID) {
        if let taken = takeQueued(turnID) { restore(taken) }
    }

    private func track(_ turnID: UUID, _ state: QueuedTurnState) {
        guard let index = composer.queue.firstIndex(where: { $0.turnID == turnID }),
              !composer.queue[index].isWithdrawing else { return }
        switch state {
        case .waiting:
            composer.queue[index].isReported = true
            markLine(composer.queue[index].lineID, queued: true)
        case .received:
            if let taken = takeQueued(turnID) { release(taken) }
            guard !isBusy else { return }
            isBusy = true
            turnStartedAt = Date()
        case .dropped:
            restoreQueued(turnID)
        }
    }

    private func takeQueued(_ turnID: UUID) -> QueuedMessage? {
        guard let index = composer.queue.firstIndex(where: { $0.turnID == turnID }) else { return nil }
        return composer.queue.remove(at: index)
    }

    private func release(_ queued: QueuedMessage) {
        if let index = lines.firstIndex(where: { $0.id == queued.lineID }) {
            var line = lines.remove(at: index)
            line.isQueued = false
            lines.append(line)
        }
        entries.removeAll { $0.id == queued.entry.id }
        entries.append(queued.entry)
        save(queued.entry)
    }

    private func restore(_ queued: QueuedMessage) {
        lines.removeAll { $0.id == queued.lineID }
        entries.removeAll { $0.id == queued.entry.id }
        let draft = isBrowsingHistory ? composer.history.draft : prompt
        composer.history.leave()
        prompt = draft.isEmpty ? queued.text : queued.text + "\n\n" + draft
        pendingAttachments = queued.attachments + pendingAttachments
    }

    private func markLine(_ lineID: UUID, queued: Bool) {
        guard let index = lines.firstIndex(where: { $0.id == lineID }) else { return }
        lines[index].isQueued = queued
    }
}
