import Foundation
import Observation

@MainActor
@Observable
final class PullRequestLedger {
    private(set) var entries: [BranchRepo.Key: PullRequestStore.Entry]
    @ObservationIgnored private let store: PullRequestStore

    init(store: PullRequestStore) {
        self.store = store
        self.entries = store.load()
    }

    func pullRequest(for key: BranchRepo.Key) -> PullRequest? { entries[key]?.pullRequest }

    func setPullRequest(_ pr: PullRequest?, for key: BranchRepo.Key) {
        let previous = entries[key]?.pullRequest
        guard previous != pr else { return }
        entries[key, default: PullRequestStore.Entry()].pullRequest = pr
        if previous?.number != pr?.number { entries[key]?.dismissed = nil }
        persist()
    }

    func isDismissed(_ key: BranchRepo.Key) -> Bool {
        guard let entry = entries[key], let pr = entry.pullRequest else { return false }
        return PullRequestStatus.isDismissed(pr, by: entry.dismissed)
    }

    func dismiss(_ key: BranchRepo.Key) {
        guard let pr = entries[key]?.pullRequest else { return }
        entries[key]?.dismissed = PullRequestStatus.signature(pr)
        persist()
    }

    func restore(_ key: BranchRepo.Key) {
        guard entries[key]?.dismissed != nil else { return }
        entries[key]?.dismissed = nil
        persist()
    }

    func keep(only branches: Set<String>) {
        let kept = entries.filter { branches.contains($0.key.branch) }
        guard kept.count != entries.count else { return }
        entries = kept
        persist()
    }

    private func persist() {
        do {
            try store.save(entries)
        } catch {
            print("não consegui gravar os PRs das branches: \(error)")
        }
    }
}
