import Foundation
import HarnessCore
import Testing
@testable import Den

@Test func everySessionLandsInTheGroupItsFolderBelongsTo() {
    let groups = SidebarGroups(sessions: [summary("on branch", in: "/dev/worktrees/NS-12/backend"),
                                          summary("on base", in: "/dev/frontend"),
                                          summary("loose", in: "/Users/me/Documents")],
                               status: sampleStatus)

    #expect(groups.branches.map(\.name) == ["NS-12", "NS-123"])
    #expect(groups.branches.map { $0.sessions.map(\.title) } == [["on branch"], []])
    #expect(groups.baseRepos.map(\.name) == ["backend", "frontend"])
    #expect(groups.baseRepos.map { $0.sessions.map(\.title) } == [[], ["on base"]])
    #expect(groups.otherFolders.map(\.name) == ["Documents"])
    #expect(groups.otherFolders.map { $0.sessions.map(\.title) } == [["loose"]])
}

@Test func sessionsOfARemovedBranchAreArchivedNewestFirst() {
    let groups = SidebarGroups(sessions: [summary("older", in: "/dev/worktrees/NS-9", updated: 1),
                                          summary("newer", in: "/dev/worktrees/NS-8/backend", updated: 2),
                                          summary("live", in: "/dev/worktrees/NS-12")],
                               status: sampleStatus)

    #expect(groups.archived.map(\.title) == ["newer", "older"])
    #expect(groups.otherFolders.isEmpty)
    #expect(groups.branches.first?.sessions.map(\.title) == ["live"])
}

@Test func withoutNsEverySessionIsAnOtherFolder() {
    let groups = SidebarGroups(sessions: [summary("a", in: "/dev/worktrees/NS-12"),
                                          summary("b", in: "/dev/frontend")],
                               status: nil)

    #expect(groups.branches.isEmpty)
    #expect(groups.baseRepos.isEmpty)
    #expect(groups.otherFolders.map(\.name).sorted() == ["NS-12", "frontend"])
}

@Test func sessionsInTheSameFolderShareOneEntryNewestFirst() {
    let groups = SidebarGroups(sessions: [summary("older", in: "/tmp/notes", updated: 1),
                                          summary("newer", in: "/tmp/notes/", updated: 2),
                                          summary("elsewhere", in: "/tmp/other", updated: 3)],
                               status: nil)

    #expect(groups.otherFolders.map(\.name) == ["other", "notes"])
    #expect(groups.otherFolders.last?.sessions.map(\.title) == ["newer", "older"])
}

@Test func searchKeepsMatchingSessionsAndGroupsNamedLikeIt() {
    let sessions = [summary("deploy notes", in: "/dev/worktrees/NS-123"),
                    summary("unrelated", in: "/dev/worktrees/NS-123")]

    let byTitle = SidebarGroups(sessions: sessions, status: sampleStatus, search: "DEPLOY")
    #expect(byTitle.branches.map(\.name) == ["NS-123"])
    #expect(byTitle.branches.first?.sessions.map(\.title) == ["deploy notes"])
    #expect(byTitle.baseRepos.isEmpty)

    let byName = SidebarGroups(sessions: sessions, status: sampleStatus, search: "backend")
    #expect(byName.branches.isEmpty)
    #expect(byName.baseRepos.map(\.name) == ["backend"])
}

@Test func nothingToShowIsEmpty() {
    #expect(SidebarGroups(sessions: [], status: nil).isEmpty)
    #expect(!SidebarGroups(sessions: [], status: sampleStatus).isEmpty)
}

@Test func aFolderKeepsADistinctIdentityInEachSection() {
    let before = SidebarGroups(sessions: [summary("root", in: "/dev/worktrees/NS-12")], status: nil)
    let after = SidebarGroups(sessions: [summary("root", in: "/dev/worktrees/NS-12")], status: sampleStatus)

    #expect(before.otherFolders.map(\.path) == after.branches.prefix(1).map(\.path))
    #expect(before.otherFolders.map(\.id) != after.branches.prefix(1).map(\.id))
}
