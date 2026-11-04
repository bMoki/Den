import Testing
import Foundation
import HarnessCore
@testable import Den

@MainActor
private struct Bench {
    let chat: ChatModel
    let worktrees: WorktreeModel
    let checkout: URL

    func launched(branch: String = "feat/ajusta-o-login") async throws -> TaskWorktree {
        let folder = checkout.deletingLastPathComponent()
            .appending(path: "worktrees/\(branch.replacingOccurrences(of: "/", with: "-"))")
        try await runGit(["worktree", "add", "-q", "-b", branch, folder.path], in: checkout)
        let made = TaskWorktree(branch: branch, sessionDirectory: folder, mirrorRoot: nil,
                                repos: [TaskWorktree.Repo(name: "api", original: checkout, worktree: folder,
                                                          base: "main", remote: nil, gitDirectory: nil)])
        worktrees.ledger.record(made, for: chat.sessionID)
        await chat.choose(directory: folder)
        return made
    }
}

@MainActor
private func withBench(_ body: (Bench) async throws -> Void) async throws {
    let scratchDefaults = ScratchDefaults()
    let parent = try makeTree(["Área de trabalho/sessions"])
    defer {
        scratchDefaults.remove()
        try? FileManager.default.removeItem(at: parent)
    }
    let scratch = parent.appending(path: "Área de trabalho")
    let checkout = try await makeRepository(at: scratch.appending(path: "api"), scratch: scratch)
    let harness = FakeHarness()
    let worktrees = WorktreeModel(
        ledger: TaskLedger(store: TaskWorktreeStore(url: scratch.appending(path: "task-worktrees.json"))))
    let bench = Bench(chat: ChatModel(store: FileTranscriptStore(root: scratch.appending(path: "sessions")),
                                      workingDirectory: checkout, harness: harness.id,
                                      cache: SessionCache(defaults: scratchDefaults.defaults),
                                      registry: HarnessRegistry(harnesses: [harness]),
                                      attachmentsRoot: scratch.appending(path: "attachments")),
                      worktrees: worktrees, checkout: checkout)
    try await body(bench)
    await bench.chat.stop()
}

@MainActor
@Test func forgettingASessionDropsItsRecord() async throws {
    try await withBench { bench in
        _ = try await bench.launched()

        bench.worktrees.forget(bench.chat.sessionID)

        #expect(bench.worktrees.worktree(for: bench.chat.sessionID) == nil)
    }
}

@MainActor
@Test func aRenameMadeByTheAgentMovesTheSessionAndItsRecord() async throws {
    try await withBench { bench in
        let made = try await bench.launched()
        let old = try #require(made.repos.first?.worktree)
        let moved = old.deletingLastPathComponent().appending(path: "feat-fix-sign-in")
        try await runGit(["branch", "-m", made.branch, "feat/fix-sign-in"], in: bench.checkout)
        try await runGit(["worktree", "move", old.path, moved.path], in: bench.checkout)

        await bench.worktrees.reconcile(bench.chat)

        let current = try #require(bench.worktrees.worktree(for: bench.chat.sessionID))
        #expect(current.branch == "feat/fix-sign-in")
        #expect(current.repos.map { $0.worktree.resolvingSymlinksInPath().path }
                == [moved.resolvingSymlinksInPath().path])
        #expect(bench.chat.workingDirectory.resolvingSymlinksInPath().path
                == moved.resolvingSymlinksInPath().path)
        #expect(bench.chat.branch == "feat/fix-sign-in")
    }
}

@MainActor
@Test func aBranchRenameAloneRefreshesTheSessionBranch() async throws {
    try await withBench { bench in
        let made = try await bench.launched()
        let folder = bench.chat.workingDirectory
        try await runGit(["branch", "-m", made.branch, "feat/fix-sign-in"], in: bench.checkout)

        await bench.worktrees.reconcile(bench.chat)

        #expect(bench.worktrees.worktree(for: bench.chat.sessionID)?.branch == "feat/fix-sign-in")
        #expect(bench.chat.workingDirectory == folder)
        #expect(bench.chat.branch == "feat/fix-sign-in")
    }
}

@MainActor
@Test func aSessionWithoutAWorktreeIsLeftAlone() async throws {
    try await withBench { bench in
        let folder = bench.chat.workingDirectory

        await bench.worktrees.reconcile(bench.chat)

        #expect(bench.chat.workingDirectory == folder)
        #expect(bench.worktrees.worktree(for: bench.chat.sessionID) == nil)
    }
}
