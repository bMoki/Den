import Foundation
import Observation

@MainActor
@Observable
final class PullRequestMonitor {
    typealias Target = BranchRepo.Key

    struct Bar: Identifiable, Equatable {
        let repo: BranchRepo
        let pullRequest: PullRequest
        var id: BranchRepo.Key { repo.id }
    }

    nonisolated private struct Item: Sendable {
        let target: Target
        let gitBranch: String
        let directory: URL
        let host: String
    }

    static let visibleInterval: TimeInterval = 20
    static let backgroundInterval: TimeInterval = 120
    static let followUpDelay: TimeInterval = 10
    static let recentWindow: TimeInterval = 7 * 24 * 60 * 60
    static let ceiling: TimeInterval = 30 * 60

    private(set) var cli: GitHubCLIState = .unknown
    private(set) var checked: [Target: Date] = [:]
    private(set) var hiddenSetup: Set<String> = []
    private(set) var repos: [BranchRepo] = []

    @ObservationIgnored private let ledger: PullRequestLedger
    @ObservationIgnored private let fetcher: any PullRequestFetching
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let limit: Int
    @ObservationIgnored private var visible: [String: Int] = [:]
    @ObservationIgnored private var activity: [String: Date] = [:]
    @ObservationIgnored private var due: [Target: Date] = [:]
    @ObservationIgnored private var followUps: [Target: Date] = [:]
    @ObservationIgnored private var inFlight: Set<Target> = []
    @ObservationIgnored private var askedHosts: Set<String> = []
    @ObservationIgnored private var watchedHosts: Set<String> = []
    @ObservationIgnored private var checkingStatus = false
    @ObservationIgnored private var refreshPending = false
    @ObservationIgnored private var penalty: Double = 1
    @ObservationIgnored private var loop: Task<Void, Never>?

    init(ledger: PullRequestLedger, fetcher: any PullRequestFetching,
         now: @escaping () -> Date = Date.init, limit: Int = 3) {
        self.ledger = ledger
        self.fetcher = fetcher
        self.now = now
        self.limit = limit
    }

    func track(_ repos: [BranchRepo], branches: Set<String>) {
        let previous = Dictionary(self.repos.map { ($0.id, $0.gitBranch) }) { first, _ in first }
        if repos != self.repos { self.repos = repos }
        ledger.keep(only: branches)
        for repo in repos where previous[repo.id].map({ $0 != repo.gitBranch }) == true || holdsAnotherBranchPullRequest(repo) {
            forgetPullRequest(of: repo)
        }
        let current = Set(repos.map(\.id))
        for target in Set(due.keys).union(checked.keys).union(followUps.keys) where !current.contains(target) {
            due[target] = nil
            checked[target] = nil
            followUps[target] = nil
        }
        hiddenSetup.formIntersection(branches)
    }

    func start() {
        guard loop == nil else { return }
        loop = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                Task { await self.tick() }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func tick() async {
        let all = items
        guard !all.isEmpty else { return }
        let hosts = Set(all.map(\.host))
        if cli == .unknown || !hosts.isSubset(of: askedHosts) {
            guard !checkingStatus else { return }
            checkingStatus = true
            if refreshPending {
                refreshPending = false
                await fetcher.refresh()
            }
            let status = await fetcher.status(hosts: hosts)
            checkingStatus = false
            apply(status, asked: hosts)
        }
        guard isReady else { return }
        let moment = now()
        let ready = all
            .filter { watchedHosts.contains($0.host) && !inFlight.contains($0.target) && isDue($0, at: moment) }
            .sorted { (due[$0.target] ?? .distantPast) < (due[$1.target] ?? .distantPast) }
            .prefix(max(0, limit - inFlight.count))
        guard !ready.isEmpty else { return }
        for item in ready { inFlight.insert(item.target) }
        let fetcher = self.fetcher
        await withTaskGroup(of: Void.self) { group in
            for item in ready {
                group.addTask {
                    let result = await fetcher.pullRequest(branch: item.gitBranch, in: item.directory)
                    await self.finish(item, with: result)
                }
            }
        }
    }

    func appear(_ branch: String) {
        visible[branch, default: 0] += 1
        scheduleNow(branch)
    }

    func disappear(_ branch: String) {
        guard let count = visible[branch] else { return }
        guard count == 1 else {
            visible[branch] = count - 1
            return
        }
        visible[branch] = nil
        for target in targets(of: branch) {
            due[target] = interval(for: target).map { (checked[target] ?? now()).addingTimeInterval($0) }
        }
    }

    func turnEnded(_ branch: String) {
        let moment = now()
        for target in targets(of: branch) {
            due[target] = moment
            followUps[target] = moment.addingTimeInterval(Self.followUpDelay)
        }
    }

    func appBecameActive() {
        if !isReady {
            cli = .unknown
            refreshPending = true
        }
        for id in visible.keys { scheduleNow(id) }
    }

    func noteActivity(_ dates: [String: Date]) {
        activity.merge(dates) { max($0, $1) }
    }

    func refresh(_ repo: BranchRepo) {
        due[repo.id] = now()
    }

    func reconfigure(path: String?) async {
        await fetcher.configure(path: path)
        hiddenSetup = []
        await checkGh()
        for id in visible.keys { scheduleNow(id) }
    }

    func checkGh() async {
        let hosts = Set(items.map(\.host)).union(["github.com"])
        apply(await fetcher.status(hosts: hosts), asked: hosts)
    }

    func repos(of branch: String) -> [BranchRepo] {
        repos.filter { $0.branch == branch }
    }

    func pullRequest(for repo: BranchRepo) -> PullRequest? {
        ledger.pullRequest(for: repo.id)
    }

    func pullRequests(for branch: String) -> [Bar] {
        repos(of: branch).compactMap { repo in
            ledger.pullRequest(for: repo.id).map { Bar(repo: repo, pullRequest: $0) }
        }
    }

    func bars(for branch: String) -> [Bar] {
        pullRequests(for: branch).filter { bar in
            ledger.dismissedSignature(for: bar.id) != PullRequestStatus.signature(bar.pullRequest)
        }
    }

    func dismiss(_ repo: BranchRepo) {
        guard let pr = ledger.pullRequest(for: repo.id) else { return }
        ledger.dismiss(repo.id, signature: PullRequestStatus.signature(pr))
    }

    func checkedAt(_ repo: BranchRepo) -> Date? {
        checked[repo.id]
    }

    func setupNeeded(for branch: String) -> GitHubCLIState? {
        guard !hiddenSetup.contains(branch),
              repos(of: branch).contains(where: { $0.remote?.host == "github.com" })
        else { return nil }
        switch cli {
        case .missing, .notLoggedIn: return cli
        case .unknown, .ready: return nil
        }
    }

    func hideSetup(for branch: String) { hiddenSetup.insert(branch) }

    private var isReady: Bool {
        if case .ready = cli { return true }
        return false
    }

    private var items: [Item] {
        repos.compactMap { repo in
            guard let remote = repo.remote, let gitBranch = repo.gitBranch else { return nil }
            return Item(target: repo.id, gitBranch: gitBranch, directory: repo.folder, host: remote.host)
        }
    }

    private func holdsAnotherBranchPullRequest(_ repo: BranchRepo) -> Bool {
        guard let pr = ledger.pullRequest(for: repo.id) else { return false }
        return (pr.head ?? repo.branch) != repo.gitBranch
    }

    private func forgetPullRequest(of repo: BranchRepo) {
        ledger.setPullRequest(nil, for: repo.id)
        checked[repo.id] = nil
        followUps[repo.id] = nil
        due[repo.id] = repo.gitBranch == nil ? nil : now()
    }

    private func targets(of branch: String) -> [Target] {
        items.map(\.target).filter { $0.branch == branch }
    }

    private func scheduleNow(_ branch: String) {
        let moment = now()
        for target in targets(of: branch) { due[target] = moment }
    }

    private func apply(_ status: GitHubCLIStatus, asked hosts: Set<String>) {
        cli = status.state
        askedHosts = hosts
        watchedHosts = status.hosts
    }

    private func isDue(_ item: Item, at moment: Date) -> Bool {
        if let follow = followUps[item.target], follow <= moment { return true }
        if let next = due[item.target] { return next <= moment }
        return checked[item.target] == nil && interval(for: item.target) != nil
    }

    private func interval(for target: Target) -> TimeInterval? {
        let pr = ledger.pullRequest(for: target)
        if let pr, pr.state != .open { return nil }
        if visible[target.branch] != nil { return Self.visibleInterval }
        if pr != nil { return Self.backgroundInterval }
        if let last = activity[target.branch], now().timeIntervalSince(last) < Self.recentWindow {
            return Self.backgroundInterval
        }
        return nil
    }

    private func finish(_ item: Item, with result: FetchResult) {
        inFlight.remove(item.target)
        if case .failed(rateLimited: true) = result { penalty = min(penalty * 2, Self.ceiling / Self.visibleInterval) }
        guard items.contains(where: { $0.target == item.target && $0.gitBranch == item.gitBranch }) else { return }
        let moment = now()
        if case .found(let pr) = result {
            ledger.setPullRequest(pr, for: item.target)
            checked[item.target] = moment
            penalty = 1
        }
        if let follow = followUps[item.target], follow <= moment { followUps[item.target] = nil }
        if let interval = interval(for: item.target) {
            due[item.target] = moment.addingTimeInterval(min(interval * penalty, Self.ceiling))
        } else {
            due[item.target] = nil
        }
    }
}
