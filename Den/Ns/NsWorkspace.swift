import Foundation
import Observation

@MainActor
@Observable
final class NsWorkspace {
    typealias BranchAction = @Sendable (_ branch: String, _ service: String?,
                                        _ progress: @escaping NsClient.Progress) async throws -> Void
    typealias UpdateBranch = @Sendable (_ branch: String,
                                        _ progress: @escaping NsClient.Progress) async throws -> NsClient.Pulled
    typealias PreviewRemoval = @Sendable (_ branch: String) async throws -> NsClient.RemovalPreview
    typealias RemoveBranch = @Sendable (_ branch: String, _ purge: Bool,
                                        _ progress: @escaping NsClient.Progress) async throws -> Void
    typealias OpenDatabase = @Sendable (_ branch: String) async throws -> Void
    typealias SetNickname = @Sendable (_ branch: String, _ nickname: String) async throws -> Void

    nonisolated struct SnapshotOperations: Sendable {
        var list: @Sendable () async throws -> [NsClient.SnapshotGroup]
        var take: @Sendable (_ branch: String, _ name: String, _ replace: Bool, _ progress: @escaping NsClient.Progress) async throws -> Void
        var restore: @Sendable (_ branch: String, _ ref: String, _ progress: @escaping NsClient.Progress) async throws -> Void
        var remove: @Sendable (_ branch: String, _ name: String) async throws -> Void

        static let unavailable: SnapshotOperations = {
            let failure = NsFailure(message: "ns indisponível")
            return SnapshotOperations(list: { throw failure },
                                      take: { _, _, _, _ in throw failure },
                                      restore: { _, _, _ in throw failure },
                                      remove: { _, _ in throw failure })
        }()
    }

    struct Activity: Equatable {
        enum Kind { case start, stop, restart, update, addRepo, remove, openDatabase, snapshot, restore, removeSnapshot }

        var kind: Kind
        var label: String
    }

    struct UpdateReport: Identifiable, Equatable {
        let branch: String
        let repos: [RepoUpdate]

        var id: String { branch }
    }

    struct Removal: Identifiable, Equatable {
        enum State: Equatable {
            case loading
            case ready(NsClient.RemovalPreview)
            case failed(String)
        }

        let id = UUID()
        let branch: String
        var state = State.loading
    }

    private(set) var status: NsStatus?
    private(set) var problem: String?
    private(set) var activity: [String: Activity] = [:]
    private(set) var actionProblems: [String: String] = [:]
    private(set) var creation: BranchCreation?
    private(set) var updateReports: [UpdateReport] = []
    private(set) var removal: Removal?
    private(set) var snapshotGroups: [NsClient.SnapshotGroup] = []
    private(set) var snapshotsProblem: String?
    private(set) var memory: NsMemory

    @ObservationIgnored private let fetch: @Sendable () async throws -> NsStatus
    @ObservationIgnored private let startBranch: BranchAction
    @ObservationIgnored private let stopBranch: BranchAction
    @ObservationIgnored private let creationOperations: BranchCreation.Operations
    @ObservationIgnored private let updateBranch: UpdateBranch
    @ObservationIgnored private let previewRemoval: PreviewRemoval
    @ObservationIgnored private let removeBranch: RemoveBranch
    @ObservationIgnored private let openBranchDatabase: OpenDatabase
    @ObservationIgnored private let saveNickname: SetNickname
    @ObservationIgnored private let snapshotOperations: SnapshotOperations
    @ObservationIgnored private let defaults: UserDefaults?
    @ObservationIgnored private var places: [URL: SessionPlace] = [:]
    @ObservationIgnored private var savingNicknames: [String: String?] = [:]

    init(fetch: @escaping @Sendable () async throws -> NsStatus,
         start: @escaping BranchAction = { _, _, _ in },
         stop: @escaping BranchAction = { _, _, _ in },
         create: BranchCreation.Operations = .unavailable,
         update: @escaping UpdateBranch = { _, _ in throw NsFailure(message: "ns indisponível") },
         previewRemoval: @escaping PreviewRemoval = { _ in throw NsFailure(message: "ns indisponível") },
         remove: @escaping RemoveBranch = { _, _, _ in throw NsFailure(message: "ns indisponível") },
         openDatabase: @escaping OpenDatabase = { _ in throw NsFailure(message: "ns indisponível") },
         setNickname: @escaping SetNickname = { _, _ in throw NsFailure(message: "ns indisponível") },
         snapshots: SnapshotOperations = .unavailable,
         defaults: UserDefaults? = nil) {
        self.fetch = fetch
        startBranch = start
        stopBranch = stop
        creationOperations = create
        updateBranch = update
        self.previewRemoval = previewRemoval
        removeBranch = remove
        openBranchDatabase = openDatabase
        saveNickname = setNickname
        snapshotOperations = snapshots
        self.defaults = defaults
        memory = NsMemory(defaults: defaults)
    }

    static func live(_ environment: any AppEnvironment) -> NsWorkspace {
        let client = NsClient.locating(override: environment.nsOverride)
        return NsWorkspace(fetch: { try await client.status() },
                           start: { try await client.start(branch: $0, service: $1, progress: $2) },
                           stop: { try await client.stop(branch: $0, service: $1, progress: $2) },
                           create: BranchCreation.Operations(
                               create: { try await client.new($0, steps: $1, ask: $2) },
                               addRepo: { try await client.addRepo(branch: $0, repo: $1, steps: $2) },
                               prepare: { try await client.prepare(branch: $0, steps: $1, ask: $2) }),
                           update: { try await client.pull(branch: $0, progress: $1) },
                           previewRemoval: { try await client.removalPreview(branch: $0) },
                           remove: { try await client.remove(branch: $0, purge: $1, progress: $2) },
                           openDatabase: { try await client.openDatabase(branch: $0) },
                           setNickname: { try await client.setNickname(branch: $0, nickname: $1) },
                           snapshots: SnapshotOperations(
                               list: { try await client.snapshots() },
                               take: { try await client.takeSnapshot(branch: $0, name: $1, replace: $2, progress: $3) },
                               restore: { try await client.restore(branch: $0, ref: $1, progress: $2) },
                               remove: { try await client.removeSnapshot(branch: $0, name: $1) }),
                           defaults: environment.defaults)
    }

    func newBranch() {
        if let creation, creation.isRunning {
            creation.isPresented = true
        } else {
            creation = makeCreation()
        }
    }

    private func makeCreation() -> BranchCreation {
        BranchCreation(operations: creationOperations) { [weak self] in await self?.refresh() }
    }

    func place(of directory: URL) -> SessionPlace {
        let (status, memory) = (status, memory)
        if let known = places[directory] { return known }
        let place = memory.place(of: directory, in: status)
        places[directory] = place
        return place
    }

    func branch(named name: String) -> NsStatus.Branch? {
        status?.branch(named: name)
    }

    func branchName(of directory: URL) -> String? {
        if case .branch(let name) = place(of: directory) { name } else { nil }
    }

    func removedBranch(of directory: URL) -> String? {
        if case .archived(let name) = place(of: directory) { name } else { nil }
    }

    func refresh() async {
        do {
            let latest = withSavingNicknames(try await fetch())
            if latest != status { status = latest }
            remember(latest)
            problem = nil
        } catch {
            problem = Self.describe(error)
        }
        places = [:]
    }

    private func remember(_ status: NsStatus) {
        let learned = memory.learned(from: status)
        guard learned != memory else { return }
        memory = learned
        learned.save(to: defaults)
    }

    func start(_ branch: String, service: String? = nil) async {
        let start = startBranch
        await run(Activity(kind: .start, label: Self.label("Iniciando", service)), on: branch) {
            try await start(branch, service, $0)
        }
    }

    func stop(_ branch: String, service: String? = nil) async {
        let stop = stopBranch
        await run(Activity(kind: .stop, label: Self.label("Parando", service)), on: branch) {
            try await stop(branch, service, $0)
        }
    }

    func restart(_ branch: String, service: String) async {
        let (stop, start) = (stopBranch, startBranch)
        await run(Activity(kind: .restart, label: Self.label("Reiniciando", service)), on: branch) {
            try await stop(branch, service, $0)
            try await start(branch, service, $0)
        }
    }

    func update(_ branch: String) async {
        let update = updateBranch
        let updated = await run(Activity(kind: .update, label: "Atualizando com a branch principal..."), on: branch) {
            try await update(branch, $0)
        }
        if let updated { updateReports.append(UpdateReport(branch: branch, repos: updated.repos)) }
    }

    func dismissUpdateReport() {
        if !updateReports.isEmpty { updateReports.removeFirst() }
    }

    func askToRemove(_ branch: String) async {
        guard activity[branch] == nil else { return }
        let request = Removal(branch: branch)
        removal = request
        let preview = previewRemoval
        let state: Removal.State
        do {
            state = .ready(try await preview(branch))
        } catch {
            state = .failed(Self.describe(error))
        }
        if removal?.id == request.id { removal?.state = state }
    }

    func cancelRemoval() {
        removal = nil
    }

    func remove(_ branch: String, purge: Bool) async {
        guard let removal, removal.branch == branch,
              case .ready(let preview) = removal.state, preview.uncommitted.isEmpty else { return }
        self.removal = nil
        let remove = removeBranch
        await run(Activity(kind: .remove, label: "Removendo..."), on: branch) {
            try await remove(branch, purge, $0)
        }
    }

    func openDatabase(_ branch: String) async {
        let open = openBranchDatabase
        await run(Activity(kind: .openDatabase, label: "Abrindo o banco..."), on: branch) { _ in
            try await open(branch)
        }
    }

    func snapshots(of branch: String) -> [NsClient.Snapshot] {
        snapshotGroups.first { $0.branch == branch }?.snapshots ?? []
    }

    func restoreSources(for branch: String) -> [NsClient.SnapshotGroup] {
        let rank = { (group: NsClient.SnapshotGroup) in
            group.orphan ? 3 : group.branch == branch ? 0 : group.branch == Self.mainBranch ? 1 : 2
        }
        return snapshotGroups.filter { !$0.snapshots.isEmpty }
            .enumerated()
            .sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }
            .map(\.element)
    }

    func loadSnapshots() async {
        do {
            let latest = try await snapshotOperations.list()
            if latest != snapshotGroups { snapshotGroups = latest }
            snapshotsProblem = nil
        } catch {
            snapshotsProblem = Self.describe(error)
        }
    }

    func takeSnapshot(_ branch: String, name: String, replacing: Bool = false) async {
        let take = snapshotOperations.take
        await run(Activity(kind: .snapshot, label: "Tirando snapshot..."), on: branch) {
            try await take(branch, name, replacing, $0)
        }
        await loadSnapshots()
    }

    func restore(_ branch: String, from ref: String) async {
        let restore = snapshotOperations.restore
        await run(Activity(kind: .restore, label: "Restaurando \(ref)..."), on: branch) {
            try await restore(branch, ref, $0)
        }
    }

    func removeSnapshot(_ snapshot: NsClient.Snapshot) async {
        let remove = snapshotOperations.remove
        await run(Activity(kind: .removeSnapshot, label: "Removendo \(snapshot.ref)..."), on: snapshot.branch) { _ in
            try await remove(snapshot.branch, snapshot.name)
        }
        await loadSnapshots()
    }

    func watch(every interval: Duration = .seconds(5), whileBusy busyInterval: Duration = .seconds(1.5)) async {
        while !Task.isCancelled {
            await refresh()
            try? await Task.sleep(for: isBusy ? busyInterval : interval)
        }
    }

    static let mainBranch = "master"

    private var isBusy: Bool {
        !activity.isEmpty || creation?.isRunning == true || status?.branches.contains { $0.services.contains { $0.state == .iniciando } } == true
    }

    @discardableResult
    private func run<Value: Sendable>(_ started: Activity, on branch: String,
                                      action: @Sendable (@escaping NsClient.Progress) async throws -> Value) async -> Value? {
        guard activity[branch] == nil else { return nil }
        activity[branch] = started
        actionProblems[branch] = nil
        let (labels, sink) = AsyncStream<String>.makeStream()
        let follow = Task { @MainActor [weak self] in
            for await label in labels { self?.activity[branch]?.label = label }
        }
        var value: Value?
        do {
            value = try await action { sink.yield($0) }
        } catch let failure as NsFailure {
            actionProblems[branch] = [failure.message, failure.hint].compactMap(\.self).joined(separator: " ")
        } catch {
            actionProblems[branch] = error.localizedDescription
        }
        sink.finish()
        await follow.value
        activity[branch] = nil
        await refresh()
        return value
    }

    private static func label(_ verb: String, _ service: String?) -> String {
        service.map { "\(verb) \($0)..." } ?? "\(verb)..."
    }

    private static func describe(_ error: any Error) -> String {
        switch error {
        case let failure as NsFailure: failure.message
        case is DecodingError: "o ns rpc respondeu num formato inesperado"
        default: "não consegui iniciar o ns rpc: \(error.localizedDescription)"
        }
    }
}

extension NsWorkspace {
    func addableRepos(of branch: String) -> [BranchCreation.Repo] {
        guard let present = self.branch(named: branch)?.repos?.map(\.repo) else { return [] }
        return BranchCreation.Repo.allCases.filter { !present.contains($0.rawValue) }
    }

    func addRepo(_ repo: BranchCreation.Repo, to branch: String) async {
        if let creation, creation.isRunning {
            creation.isPresented = true
            return
        }
        guard activity[branch] == nil else { return }
        let creation = makeCreation()
        self.creation = creation
        await holding(branch, adding: repo) { await creation.add(repo, to: branch) }
    }

    func holdingBranch(of creation: BranchCreation, while work: () async -> Void) async {
        guard let repo = creation.adding else {
            await work()
            return
        }
        await holding(creation.name, adding: repo, while: work)
    }

    private func holding(_ branch: String, adding repo: BranchCreation.Repo, while work: () async -> Void) async {
        let isFree = activity[branch] == nil
        if isFree {
            activity[branch] = Activity(kind: .addRepo, label: "Incluindo \(repo.rawValue)...")
            actionProblems[branch] = nil
        }
        await work()
        if isFree { activity[branch] = nil }
    }

    func setNickname(_ branch: String, to text: String) async {
        let nickname = BranchNickname.normalized(text)
        guard let index = status?.branches.firstIndex(where: { $0.branch == branch }),
              status?.branches[index].nickname != nickname else { return }
        status?.branches[index].nickname = nickname
        savingNicknames[branch] = nickname
        do {
            try await saveNickname(branch, nickname ?? "")
            actionProblems[branch] = nil
        } catch {
            actionProblems[branch] = Self.describe(error)
        }
        savingNicknames[branch] = nil
        await refresh()
    }

    private func withSavingNicknames(_ status: NsStatus) -> NsStatus {
        var status = status
        for (branch, nickname) in savingNicknames {
            if let index = status.branches.firstIndex(where: { $0.branch == branch }) {
                status.branches[index].nickname = nickname
            }
        }
        return status
    }
}
