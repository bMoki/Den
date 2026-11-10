import Testing
import Foundation
@testable import Thalamus

@MainActor
private final class TestClock {
    var now = Date(timeIntervalSince1970: 1_800_000_000)
    func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

@MainActor
private struct Rig {
    let monitor: PullRequestMonitor
    let ledger: PullRequestLedger
    let fetcher: FakeFetcher
    let clock: TestClock
    let branches: [String]

    func repo(_ index: Int) -> BranchRepo { monitor.repos(of: branches[index])[0] }

    func ticked(after seconds: TimeInterval) async -> Int {
        clock.advance(seconds)
        await monitor.tick()
        return await fetcher.calls.count
    }
}

func branchRepo(_ branch: String, _ name: String = "api", host: String = "github.com", gitBranch: String? = nil) -> BranchRepo {
    BranchRepo(branch: branch, name: name, folder: URL(fileURLWithPath: "/wt/\(branch)/\(name)"),
               remote: GitHubRemote(host: host, owner: "thalamus", name: name), gitBranch: gitBranch ?? branch)
}

@MainActor
private func makeRig(branches: Int = 1, host: String = "github.com", limit: Int = 3) -> Rig {
    let file = FileManager.default.temporaryDirectory
        .appending(path: "ThalamusTests-" + UUID().uuidString).appending(path: "pull-requests.json")
    let ledger = PullRequestLedger(store: PullRequestStore(url: file))
    let names = (0..<branches).map { "NS-\($0)" }
    let fetcher = FakeFetcher()
    let clock = TestClock()
    let monitor = PullRequestMonitor(ledger: ledger, fetcher: fetcher, now: { clock.now }, limit: limit)
    monitor.track(names.map { branchRepo($0, host: host) }, branches: Set(names))
    return Rig(monitor: monitor, ledger: ledger, fetcher: fetcher, clock: clock, branches: names)
}

@MainActor
@Test func aVisibleBranchIsCheckedEveryTwentySeconds() async {
    let rig = makeRig()
    rig.monitor.appear(rig.branches[0])

    await rig.monitor.tick()
    #expect(await rig.ticked(after: 19) == 1)

    #expect(await rig.ticked(after: 1) == 2)
}

@MainActor
@Test func aHiddenBranchWithAnOpenPullRequestIsCheckedEveryTwoMinutes() async {
    let rig = makeRig()
    rig.ledger.setPullRequest(makePullRequest(), for: rig.repo(0).id)
    await rig.fetcher.answer(.found(makePullRequest()))

    await rig.monitor.tick()
    #expect(await rig.ticked(after: 119) == 1)

    #expect(await rig.ticked(after: 1) == 2)
}

@MainActor
@Test func anOldHiddenBranchWithoutPullRequestWaitsUntilOpened() async {
    let rig = makeRig()
    rig.monitor.noteActivity([rig.branches[0]: rig.clock.now.addingTimeInterval(-8 * 24 * 3600)])

    await rig.monitor.tick()
    #expect(await rig.fetcher.calls.isEmpty)

    rig.monitor.appear(rig.branches[0])
    await rig.monitor.tick()
    #expect(await rig.fetcher.calls.count == 1)
}

@MainActor
@Test func aRecentHiddenBranchWithoutPullRequestIsWatched() async {
    let rig = makeRig()
    rig.monitor.noteActivity([rig.branches[0]: rig.clock.now.addingTimeInterval(-24 * 3600)])

    await rig.monitor.tick()
    #expect(await rig.ticked(after: 119) == 1)

    #expect(await rig.ticked(after: 1) == 2)
}

@MainActor
@Test func theEndOfATurnChecksNowAndTenSecondsLater() async {
    let rig = makeRig()
    rig.monitor.appear(rig.branches[0])
    await rig.monitor.tick()

    rig.clock.advance(5)
    rig.monitor.turnEnded(rig.branches[0])
    await rig.monitor.tick()
    #expect(await rig.fetcher.calls.count == 2)

    #expect(await rig.ticked(after: 9) == 2)

    #expect(await rig.ticked(after: 1) == 3)
}

@MainActor
@Test func aMergedPullRequestIsNotCheckedAgainUntilReopened() async {
    let rig = makeRig()
    await rig.fetcher.answer(.found(makePullRequest(state: .merged)))
    rig.monitor.appear(rig.branches[0])
    await rig.monitor.tick()

    #expect(await rig.ticked(after: 600) == 1)

    rig.monitor.disappear(rig.branches[0])
    rig.monitor.appear(rig.branches[0])
    await rig.monitor.tick()
    #expect(await rig.fetcher.calls.count == 2)
}

@MainActor
@Test func aBranchStaysVisibleUntilItsLastWindowGoes() async {
    let rig = makeRig()
    rig.monitor.appear(rig.branches[0])
    rig.monitor.appear(rig.branches[0])
    await rig.monitor.tick()

    rig.monitor.disappear(rig.branches[0])
    #expect(await rig.ticked(after: 20) == 2)

    rig.monitor.disappear(rig.branches[0])
    #expect(await rig.ticked(after: 20) == 2)
}

@MainActor
@Test func neverMoreThanThreeChecksAtOnce() async {
    let rig = makeRig(branches: 5)
    for branch in rig.branches { rig.monitor.appear(branch) }
    await rig.fetcher.holdFetches()

    let first = Task { await rig.monitor.tick() }
    #expect(await eventually { await rig.fetcher.running == 3 })
    await rig.monitor.tick()
    #expect(await rig.fetcher.calls.count == 3)

    await rig.fetcher.release()
    await first.value
    await rig.monitor.tick()

    #expect(await rig.fetcher.calls.count == 5)
    #expect(await rig.fetcher.peak == 3)
}

@MainActor
@Test func aSlowStatusCheckIsNotRepeatedMeanwhile() async {
    let rig = makeRig()
    rig.monitor.appear(rig.branches[0])
    await rig.fetcher.holdStatus()

    let first = Task { await rig.monitor.tick() }
    #expect(await eventually { await rig.fetcher.statusCalls == 1 })
    await rig.monitor.tick()
    await rig.monitor.tick()
    #expect(await rig.fetcher.statusCalls == 1)

    await rig.fetcher.release()
    await first.value
    #expect(rig.monitor.cli == .ready(path: "/fake/gh", version: "1.0"))
}

@MainActor
@Test func rateLimitsStretchTheIntervalUntilACheckWorks() async {
    let rig = makeRig()
    await rig.fetcher.answer(.failed(rateLimited: true))
    rig.monitor.appear(rig.branches[0])
    await rig.monitor.tick()

    #expect(await rig.ticked(after: 20) == 1)
    #expect(await rig.ticked(after: 20) == 2)

    await rig.fetcher.answer(.found(nil))
    #expect(await rig.ticked(after: 79) == 2)
    #expect(await rig.ticked(after: 1) == 3)

    #expect(await rig.ticked(after: 20) == 4)
}

@MainActor
@Test func aDismissedBarComesBackWhenTheStateChanges() async {
    let rig = makeRig()
    await rig.fetcher.answer(.found(makePullRequest(checks: [.passed])))
    rig.monitor.appear(rig.branches[0])
    await rig.monitor.tick()
    #expect(rig.monitor.bars(for: rig.branches[0]).count == 1)

    rig.monitor.dismiss(rig.repo(0))
    #expect(rig.monitor.bars(for: rig.branches[0]).isEmpty)
    #expect(rig.monitor.pullRequests(for: rig.branches[0]).count == 1)

    await rig.fetcher.answer(.found(makePullRequest(checks: [.failed])))
    rig.clock.advance(20)
    await rig.monitor.tick()
    #expect(rig.monitor.bars(for: rig.branches[0]).count == 1)
    #expect(rig.monitor.checkedAt(rig.repo(0)) == rig.clock.now)
}

@MainActor
@Test func theSameActionDismissesAndBringsBackAPullRequest() {
    let rig = makeRig()
    let repo = rig.repo(0)
    rig.ledger.setPullRequest(makePullRequest(checks: [.failed]), for: repo.id)

    rig.monitor.toggleDismissal(of: repo)
    #expect(rig.monitor.isDismissed(repo))
    #expect(rig.monitor.bars(for: rig.branches[0]).isEmpty)

    rig.monitor.toggleDismissal(of: repo)
    #expect(!rig.monitor.isDismissed(repo))
    #expect(rig.monitor.bars(for: rig.branches[0]).count == 1)
}

@MainActor
@Test func aDismissedMergedPullRequestStaysAwayButANewOneShows() {
    let rig = makeRig()
    let repo = rig.repo(0)
    rig.ledger.setPullRequest(makePullRequest(number: 7, state: .merged, checks: [.running]), for: repo.id)
    rig.monitor.dismiss(repo)

    rig.ledger.setPullRequest(makePullRequest(number: 7, state: .merged, mergeable: .unknown, checks: [.passed]),
                              for: repo.id)
    #expect(rig.monitor.isDismissed(repo))

    rig.ledger.setPullRequest(makePullRequest(number: 8, state: .merged), for: repo.id)
    #expect(!rig.monitor.isDismissed(repo))
}

@MainActor
@Test func aPullRequestDismissedWhileOpenComesBackWhenMerged() {
    let rig = makeRig()
    let repo = rig.repo(0)
    rig.ledger.setPullRequest(makePullRequest(number: 7, review: .approved), for: repo.id)
    rig.monitor.dismiss(repo)

    rig.ledger.setPullRequest(makePullRequest(number: 7, state: .merged, review: .approved), for: repo.id)
    #expect(!rig.monitor.isDismissed(repo))
}

@MainActor
@Test func aMissingGhStopsTheChecksUntilItIsBack() async {
    let rig = makeRig()
    await rig.fetcher.set(state: .missing)
    rig.monitor.appear(rig.branches[0])
    await rig.monitor.tick()

    #expect(rig.monitor.cli == .missing)
    #expect(rig.monitor.setupNeeded(for: rig.branches[0]) == .missing)
    #expect(await rig.fetcher.calls.isEmpty)

    await rig.fetcher.set(state: .ready(path: "/fake/gh", version: "1.0"))
    rig.monitor.appBecameActive()
    await rig.monitor.tick()
    #expect(rig.monitor.setupNeeded(for: rig.branches[0]) == nil)
    #expect(await rig.fetcher.calls.count == 1)
}

@MainActor
@Test func reconfiguringHandsThePathOverAndChecksAgain() async {
    let rig = makeRig()
    await rig.fetcher.set(state: .missing)
    rig.monitor.appear(rig.branches[0])
    await rig.monitor.tick()
    rig.monitor.hideSetup(for: rig.branches[0])
    #expect(rig.monitor.setupNeeded(for: rig.branches[0]) == nil)

    await rig.fetcher.set(state: .notLoggedIn(host: "github.com"))
    await rig.monitor.reconfigure(path: "/opt/gh")

    #expect(await rig.fetcher.configured == ["/opt/gh"])
    #expect(rig.monitor.cli == .notLoggedIn(host: "github.com"))
    #expect(rig.monitor.setupNeeded(for: rig.branches[0]) == .notLoggedIn(host: "github.com"))
}

@MainActor
@Test func onlyLoggedInHostsAreWatched() async {
    let rig = makeRig(host: "git.acme.com")
    rig.monitor.appear(rig.branches[0])
    await rig.monitor.tick()

    #expect(await rig.fetcher.calls.isEmpty)
    #expect(rig.monitor.setupNeeded(for: rig.branches[0]) == nil)
}

@MainActor
@Test func noBranchReposMeansNoGhAtAll() async {
    let rig = makeRig(branches: 0)
    await rig.monitor.tick()

    #expect(await rig.fetcher.statusCalls == 0)
    #expect(rig.monitor.cli == .unknown)
}

@MainActor
@Test func comingBackToTheAppRefreshesGhBeforeCheckingAgain() async {
    let rig = makeRig()
    await rig.fetcher.set(state: .missing)
    rig.monitor.appear(rig.branches[0])
    await rig.monitor.tick()
    #expect(await rig.fetcher.refreshes == 0)

    rig.monitor.appBecameActive()
    await rig.monitor.tick()

    #expect(await rig.fetcher.refreshes == 1)
    #expect(await rig.fetcher.statusCalls == 2)
}

@MainActor
@Test func comingBackWhileReadyLeavesGhAlone() async {
    let rig = makeRig()
    rig.monitor.appear(rig.branches[0])
    await rig.monitor.tick()

    rig.monitor.appBecameActive()
    await rig.monitor.tick()

    #expect(await rig.fetcher.refreshes == 0)
}

@MainActor
@Test func twoBranchesWithTheSameRepoAreCheckedApart() async {
    let rig = makeRig(branches: 2)
    rig.monitor.appear(rig.branches[0])
    rig.monitor.appear(rig.branches[1])
    await rig.fetcher.answer(.found(makePullRequest(number: 7)))

    await rig.monitor.tick()

    #expect(Set(await rig.fetcher.calls) == ["/wt/NS-0/api", "/wt/NS-1/api"])
    #expect(rig.monitor.pullRequests(for: "NS-0").map(\.repo.id) == [BranchRepo.Key(branch: "NS-0", repo: "api")])
    #expect(rig.monitor.pullRequests(for: "NS-1").map(\.pullRequest.number) == [7])
}

@MainActor
@Test func aBranchShowsOnePullRequestPerRepo() {
    let rig = makeRig(branches: 0)
    let backend = branchRepo("NS-9", "backend")
    let frontend = branchRepo("NS-9", "frontend")
    rig.monitor.track([backend, frontend, branchRepo("NS-10", "backend")], branches: ["NS-9", "NS-10"])
    rig.ledger.setPullRequest(makePullRequest(number: 1), for: backend.id)
    rig.ledger.setPullRequest(makePullRequest(number: 2), for: frontend.id)

    #expect(rig.monitor.repos(of: "NS-9") == [backend, frontend])
    #expect(rig.monitor.pullRequests(for: "NS-9").map(\.pullRequest.number) == [1, 2])
    #expect(rig.monitor.pullRequests(for: "NS-10").isEmpty)
}

@MainActor
@Test func aBranchThatLeavesTheWorkspaceStopsBeingChecked() async {
    let rig = makeRig()
    rig.monitor.appear(rig.branches[0])
    await rig.monitor.tick()

    rig.monitor.track([], branches: [])

    #expect(await rig.ticked(after: 20) == 1)
}

@MainActor
@Test func theRepoIsCheckedByTheGitBranchItHasCheckedOut() async {
    let rig = makeRig()
    rig.monitor.track([branchRepo("NS-0", gitBranch: "fix/trocada")], branches: ["NS-0"])
    rig.monitor.appear("NS-0")

    await rig.monitor.tick()

    #expect(await rig.fetcher.branches == ["fix/trocada"])
}

@MainActor
@Test func switchingTheGitBranchDropsTheOldPullRequestAndChecksAtOnce() async {
    let rig = makeRig()
    var old = makePullRequest(number: 7)
    old.head = "NS-0"
    rig.ledger.setPullRequest(old, for: rig.repo(0).id)
    await rig.fetcher.answer(.found(makePullRequest(number: 9)))

    rig.monitor.track([branchRepo("NS-0", gitBranch: "outra")], branches: ["NS-0"])
    #expect(rig.monitor.pullRequest(for: rig.repo(0)) == nil)

    await rig.monitor.tick()
    #expect(await rig.fetcher.branches == ["outra"])
    #expect(rig.monitor.pullRequest(for: rig.repo(0))?.number == 9)
}

@MainActor
@Test func aPullRequestSavedForAnotherGitBranchIsDroppedWhenTheAppStarts() {
    let rig = makeRig()
    var saved = makePullRequest(number: 7)
    saved.head = "NS-0"
    rig.ledger.setPullRequest(saved, for: rig.repo(0).id)
    rig.monitor.track([branchRepo("NS-0", gitBranch: "NS-0")], branches: ["NS-0"])
    #expect(rig.monitor.pullRequest(for: rig.repo(0))?.number == 7)

    let fresh = PullRequestMonitor(ledger: rig.ledger, fetcher: rig.fetcher, now: { rig.clock.now })
    fresh.track([branchRepo("NS-0", gitBranch: "outra")], branches: ["NS-0"])

    #expect(fresh.pullRequest(for: rig.repo(0)) == nil)
}

@MainActor
@Test func aRepoInDetachedHeadHasNoPullRequestAndIsNeverChecked() async {
    let rig = makeRig()
    rig.ledger.setPullRequest(makePullRequest(), for: rig.repo(0).id)
    let detached = BranchRepo(branch: "NS-0", name: "api", folder: URL(fileURLWithPath: "/wt/NS-0/api"),
                              remote: GitHubRemote(host: "github.com", owner: "thalamus", name: "api"), gitBranch: nil)

    rig.monitor.track([detached], branches: ["NS-0"])
    rig.monitor.appear("NS-0")
    await rig.monitor.tick()

    #expect(rig.monitor.pullRequest(for: detached) == nil)
    #expect(rig.monitor.bars(for: "NS-0").isEmpty)
    #expect(await rig.fetcher.calls.isEmpty)
}

@MainActor
@Test func anAnswerForTheGitBranchTheRepoLeftIsDiscarded() async {
    let rig = makeRig()
    rig.monitor.appear("NS-0")
    await rig.fetcher.holdFetches()
    await rig.fetcher.answer(.found(makePullRequest(number: 3)))

    let checking = Task { await rig.monitor.tick() }
    while await rig.fetcher.running == 0 { await Task.yield() }
    rig.monitor.track([branchRepo("NS-0", gitBranch: "outra")], branches: ["NS-0"])
    await rig.fetcher.release()
    await checking.value

    #expect(rig.monitor.pullRequest(for: rig.repo(0)) == nil)
}
