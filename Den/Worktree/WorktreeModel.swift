import Foundation
import Observation

@MainActor
@Observable
final class WorktreeModel {
    @ObservationIgnored let ledger: TaskLedger

    init(ledger: TaskLedger) {
        self.ledger = ledger
    }

    func worktree(for id: UUID) -> TaskWorktree? { ledger.worktree(for: id) }

    func reconcile(_ chat: ChatModel) async {
        let id = chat.sessionID
        guard let recorded = ledger.worktree(for: id) else { return }
        let current = await Task.detached { WorktreeLocator.current(recorded) }.value
        guard ledger.worktree(for: id) == recorded else { return }
        ledger.update(current, for: id)
        if current.sessionDirectory.path != chat.workingDirectory.path {
            await chat.choose(directory: current.sessionDirectory)
        } else if current.branch != chat.branch {
            await chat.loadBranch()
        }
    }

    func forget(_ id: UUID) {
        ledger.forget(id)
    }
}
