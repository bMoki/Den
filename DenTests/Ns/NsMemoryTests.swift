import Foundation
import Testing
@testable import Den

private func temporaryFolder() throws -> URL {
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
}

private func linkedFolder() throws -> (real: URL, link: URL) {
    let real = try temporaryFolder()
    let link = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)
    return (real, link)
}

private func remove(_ folders: (real: URL, link: URL)) {
    try? FileManager.default.removeItem(at: folders.link)
    try? FileManager.default.removeItem(at: folders.real)
}

@Test func withoutNsARemovedBranchUnderTheRememberedWorktreesFolderIsArchived() throws {
    let worktrees = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: worktrees) }
    let memory = NsMemory(worktreesDir: worktrees.path)

    #expect(memory.place(of: worktrees.appending(path: "NS-8/backend"), in: nil) == .archived("NS-8"))
}

@Test func withoutNsALiveFolderIsNotArchived() throws {
    let worktrees = try temporaryFolder()
    try FileManager.default.createDirectory(at: worktrees.appending(path: "NS-7"), withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: worktrees) }
    let memory = NsMemory(worktreesDir: worktrees.path, branches: ["NS-7": worktrees.appending(path: "NS-7").path])

    #expect(memory.place(of: worktrees.appending(path: "NS-7"), in: nil) == .elsewhere)
}

@Test func aRememberedBranchOutsideTheWorktreesFolderIsArchivedOnceItsFolderIsGone() throws {
    let elsewhere = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: elsewhere) }
    let memory = NsMemory(branches: ["feature/x": elsewhere.appending(path: "x").path])

    #expect(memory.place(of: elsewhere.appending(path: "x/web"), in: nil) == .archived("feature/x"))
    #expect(memory.place(of: elsewhere.appending(path: "y"), in: nil) == .elsewhere)
}

@Test func aLiveBranchWinsOverWhatWasRemembered() {
    let memory = NsMemory(worktreesDir: "/dev/old", branches: ["NS-12": "/dev/old/NS-12"])

    #expect(memory.place(of: URL(fileURLWithPath: "/dev/worktrees/NS-12"), in: sampleStatus) == .branch("NS-12"))
}

@Test func aWorktreesFolderBehindASymbolicLinkStillArchivesItsRemovedBranches() throws {
    let folders = try linkedFolder()
    defer { remove(folders) }
    let (real, link) = folders
    let status = NsStatus(worktreesDir: real.path, baseRepos: [], branches: [])

    #expect(status.place(of: link.appending(path: "NS-8/backend")) == .archived("NS-8"))
    #expect(NsMemory(worktreesDir: link.path).place(of: real.appending(path: "NS-8"), in: nil) == .archived("NS-8"))
    #expect(NsMemory(worktreesDir: real.path).place(of: link.appending(path: "NS-8"), in: nil) == .archived("NS-8"))
}

@Test func theMemoryKeepsTheLiveBranchesAndOnlyTheRemovedOnesTheWorktreesFolderCannotExplain() {
    let memory = NsMemory(branches: ["NS-1": "/dev/worktrees/NS-1", "feature/x": "/elsewhere/x"])

    let learned = memory.learned(from: sampleStatus)

    #expect(learned.worktreesDir == "/dev/worktrees")
    #expect(learned.branches == ["feature/x": "/elsewhere/x", "NS-12": "/dev/worktrees/NS-12", "NS-123": "/dev/worktrees/NS-123"])
}

@Test func withoutNsAFolderMissingInsideALiveBranchIsNotArchivedUnderAWrongName() throws {
    let worktrees = try temporaryFolder()
    try FileManager.default.createDirectory(at: worktrees.appending(path: "NS-8"), withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: worktrees) }
    let memory = NsMemory(worktreesDir: worktrees.path, branches: ["NS-8": worktrees.appending(path: "NS-8").path])

    #expect(memory.place(of: worktrees.appending(path: "NS-8/backend"), in: nil) == .elsewhere)
}

@Test func aLiveBranchReachedThroughASymbolicLinkStillBelongsToIt() throws {
    let folders = try linkedFolder()
    defer { remove(folders) }
    let (real, link) = folders
    try FileManager.default.createDirectory(at: real.appending(path: "NS-7"), withIntermediateDirectories: true)
    let status = NsStatus(worktreesDir: real.path, baseRepos: [], branches: [.init(branch: "NS-7", path: real.appending(path: "NS-7").path)])

    #expect(status.place(of: link.appending(path: "NS-7/backend")) == .branch("NS-7"))
}

@Test func theWorkspaceRemembersBetweenRunsAndArchivesBeforeNsAnswers() async throws {
    let suite = "ThalamusTests.nsMemory.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let first = NsWorkspace(fetch: { sampleStatus }, defaults: defaults)
    await first.refresh()

    let next = NsWorkspace(fetch: { throw NsFailure(message: "ns indisponível") }, defaults: defaults)
    #expect(next.removedBranch(of: URL(fileURLWithPath: "/dev/worktrees/NS-12/backend")) == "NS-12")
    await next.refresh()
    #expect(next.status == nil)
    #expect(next.removedBranch(of: URL(fileURLWithPath: "/dev/worktrees/NS-12/backend")) == "NS-12")
    #expect(next.removedBranch(of: URL(fileURLWithPath: "/Users/me/notes")) == nil)
}
