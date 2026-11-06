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
        guard entries[key]?.pullRequest != pr else { return }
        entries[key, default: PullRequestStore.Entry()].pullRequest = pr
        persist()
    }

    func dismissedSignature(for key: BranchRepo.Key) -> String? { entries[key]?.dismissed }

    func dismiss(_ key: BranchRepo.Key, signature: String) {
        entries[key, default: PullRequestStore.Entry()].dismissed = signature
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
