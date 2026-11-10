import Testing
import Foundation
@testable import Thalamus

@Test func theReposOfABranchAreTheBaseReposCheckedOutInItsFolder() throws {
    let root = try makeTree(["base/backend/.git", "base/frontend/.git", "wt/NS-1/backend", "wt/NS-2/frontend"],
                            files: ["wt/NS-1/backend/.git", "wt/NS-2/frontend/.git"])
    try "[core]\n\tbare = false\n[remote \"origin\"]\n\turl = git@github.com:thalamus/backend.git\n"
        .write(to: root.appending(path: "base/backend/.git/config"), atomically: true, encoding: .utf8)
    let status = NsStatus(worktreesDir: root.appending(path: "wt").path,
                          baseRepos: [.init(repo: "backend", path: root.appending(path: "base/backend").path),
                                      .init(repo: "frontend", path: root.appending(path: "base/frontend").path)],
                          branches: [.init(branch: "NS-1", path: root.appending(path: "wt/NS-1").path),
                                     .init(branch: "NS-2", path: root.appending(path: "wt/NS-2").path)])

    let repos = BranchRepo.list(in: status)

    #expect(repos.map(\.id) == [.init(branch: "NS-1", repo: "backend"), .init(branch: "NS-2", repo: "frontend")])
    #expect(repos[0].folder.path == root.appending(path: "wt/NS-1/backend").path)
    #expect(repos[0].remote == GitHubRemote(host: "github.com", owner: "thalamus", name: "backend"))
    #expect(repos[1].remote == nil)
}

@MainActor
@Test func pullRequestsAndDismissalsAreKeptPerBranchAndRepo() {
    let file = FileManager.default.temporaryDirectory
        .appending(path: "ThalamusTests-" + UUID().uuidString).appending(path: "pull-requests.json")
    let ledger = PullRequestLedger(store: PullRequestStore(url: file))
    let backend = BranchRepo.Key(branch: "feat/NS-1", repo: "backend")
    let pr = makePullRequest(number: 12)

    ledger.setPullRequest(pr, for: backend)
    ledger.dismiss(backend)

    let reloaded = PullRequestLedger(store: PullRequestStore(url: file))
    #expect(reloaded.pullRequest(for: backend) == pr)
    #expect(reloaded.isDismissed(backend))
    #expect(reloaded.pullRequest(for: .init(branch: "feat/NS-1", repo: "frontend")) == nil)
    #expect(reloaded.pullRequest(for: .init(branch: "NS-2", repo: "backend")) == nil)
}

@Test func anUnreadablePullRequestFileIsSetAside() throws {
    let root = try makeTree([])
    let file = root.appending(path: "pull-requests.json")
    try Data("{ quebrado".utf8).write(to: file)

    #expect(PullRequestStore(url: file).load().isEmpty)
    #expect(!FileManager.default.fileExists(atPath: file.path))
}

@MainActor
@Test func twoSessionsOnTheSameBranchShareItsPullRequests() async {
    let file = FileManager.default.temporaryDirectory
        .appending(path: "ThalamusTests-" + UUID().uuidString).appending(path: "pull-requests.json")
    let fetcher = FakeFetcher()
    let monitor = PullRequestMonitor(ledger: PullRequestLedger(store: PullRequestStore(url: file)), fetcher: fetcher)
    monitor.track([branchRepo("NS-1")], branches: ["NS-1"])
    await fetcher.answer(.found(makePullRequest(number: 3)))

    monitor.appear("NS-1")
    monitor.appear("NS-1")
    await monitor.tick()

    #expect(await fetcher.calls == ["/wt/NS-1/api"])
    #expect(monitor.bars(for: "NS-1").map(\.pullRequest.number) == [3])

    monitor.dismiss(monitor.repos(of: "NS-1")[0])
    #expect(monitor.bars(for: "NS-1").isEmpty)
    #expect(monitor.pullRequests(for: "NS-1").count == 1)
}

@MainActor
@Test func aRemovedBranchTakesItsPullRequestsAlong() {
    let file = FileManager.default.temporaryDirectory
        .appending(path: "ThalamusTests-" + UUID().uuidString).appending(path: "pull-requests.json")
    let ledger = PullRequestLedger(store: PullRequestStore(url: file))
    let monitor = PullRequestMonitor(ledger: ledger, fetcher: FakeFetcher())
    let gone = branchRepo("NS-1")
    let kept = branchRepo("NS-2")
    monitor.track([gone, kept], branches: ["NS-1", "NS-2"])
    ledger.setPullRequest(makePullRequest(state: .merged), for: gone.id)
    ledger.setPullRequest(makePullRequest(number: 2), for: kept.id)

    monitor.track([kept], branches: ["NS-2"])
    monitor.track([gone, kept], branches: ["NS-1", "NS-2"])

    #expect(monitor.pullRequests(for: "NS-1").isEmpty)
    #expect(PullRequestLedger(store: PullRequestStore(url: file)).pullRequest(for: kept.id)?.number == 2)
}

@Test func eachRepoCarriesTheGitBranchNsReportsForIt() throws {
    let root = try makeTree(["base/backend/.git", "base/frontend/.git", "wt/NS-1/backend", "wt/NS-1/frontend"],
                            files: ["wt/NS-1/backend/.git", "wt/NS-1/frontend/.git"])
    let bases: [NsStatus.BaseRepo] = [.init(repo: "backend", path: root.appending(path: "base/backend").path),
                                      .init(repo: "frontend", path: root.appending(path: "base/frontend").path)]
    let path = root.appending(path: "wt/NS-1").path
    let reported = NsStatus(worktreesDir: nil, baseRepos: bases, branches: [
        .init(branch: "NS-1", path: path, repos: [.init(repo: "backend", gitBranch: "fix/outra"),
                                                  .init(repo: "frontend", gitBranch: nil)]),
    ])
    let older = NsStatus(worktreesDir: nil, baseRepos: bases, branches: [.init(branch: "NS-1", path: path)])

    #expect(BranchRepo.list(in: reported).map(\.gitBranch) == ["fix/outra", nil])
    #expect(BranchRepo.list(in: older).map(\.gitBranch) == ["NS-1", "NS-1"])
}
