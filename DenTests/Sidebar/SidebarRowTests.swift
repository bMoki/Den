import Foundation
import Testing
import HarnessCore
@testable import Den

@Test func aRowNeverOpenedChoosesTheSessionWithTheLatestActivity() {
    let older = summary("older", updated: 1)
    let newer = summary("newer", updated: 2)

    #expect(SessionOpenings().lastOpened(among: [older, newer]) == newer.id)
    #expect(SessionOpenings().lastOpened(among: []) == nil)
}

@Test func aRowChoosesTheSessionOpenedLastOverOneWithNewerActivity() {
    let opened = summary("opened", updated: 1)
    let busier = summary("busier", updated: 5)
    var openings = SessionOpenings()
    openings.note(opened.id, at: Date(timeIntervalSince1970: 10))

    #expect(openings.lastOpened(among: [opened, busier]) == opened.id)

    openings.note(busier.id, at: Date(timeIntervalSince1970: 20))
    #expect(openings.lastOpened(among: [opened, busier]) == busier.id)

    openings.forget(busier.id)
    #expect(openings.lastOpened(among: [opened, busier]) == opened.id)
}

@Test func aSessionBelongsToTheRowOfItsPlace() {
    let directory = URL(fileURLWithPath: "/Users/me/Documents/")

    #expect(SidebarRow(.branch("NS-12"), directory: directory) == .branch("NS-12"))
    #expect(SidebarRow(.baseRepo("frontend"), directory: directory) == .baseRepo("frontend"))
    #expect(SidebarRow(.archived("NS-9"), directory: directory) == .archived)
    #expect(SidebarRow(.elsewhere, directory: directory) == .folder("/Users/me/Documents"))
}

@Test func eachFolderOfTheSidebarIsFoundByItsRowIncludingFavorites() throws {
    let loose = [summary("loose", in: "/Users/me/Documents")]
    let plain = SidebarGroups(sessions: loose, status: sampleStatus)
    let favorite = try #require(plain.branches.first).favorite
    let groups = SidebarGroups(sessions: loose, status: sampleStatus, layout: SidebarLayout(favorites: [favorite]))

    #expect(groups.folder(.branch("NS-12"))?.kind == .branch)
    #expect(groups.folder(.baseRepo("frontend"))?.name == "frontend")
    #expect(groups.folder(.folder("/Users/me/Documents"))?.sessions.map(\.title) == ["loose"])
    #expect(groups.folder(.branch("NS-9")) == nil)
    #expect(groups.folders.map { SidebarRow($0) }.contains(.branch("NS-12")))
}

@Test func clickingARowOpensItsChosenSessionAndClickingAgainOpensItsPage() async throws {
    try await withWorkspace { harness in
        let first = storedSession("first")
        let second = storedSession("second")
        try await harness.store.saveMetadata(first)
        try await harness.store.saveMetadata(second)
        await harness.model.refresh()
        await harness.model.select(first.id)
        let sessions = harness.model.summaries

        await harness.model.open(.folder("/code/project"), among: sessions, reselected: false)
        #expect(harness.model.selectedID == first.id)
        #expect(harness.model.page == nil)

        await harness.model.open(.folder("/code/project"), among: sessions, reselected: true)
        #expect(harness.model.page == .folder("/code/project"))
        #expect(harness.model.selectedID == first.id)

        await harness.model.select(second.id)
        #expect(harness.model.page == nil)
    }
}

@Test func aRowWithoutSessionsOpensItsPage() async throws {
    try await withWorkspace { harness in
        await harness.model.open(.baseRepo("frontend"), among: [], reselected: false)

        #expect(harness.model.page == .baseRepo("frontend"))
        #expect(harness.model.selectedID == nil)
    }
}

@Test func theLastOpenedSessionIsRememberedAcrossLaunchesAndForgottenWhenDeleted() async throws {
    try await withWorkspace { harness in
        let kept = storedSession("kept")
        let deleted = storedSession("deleted")
        try await harness.store.saveMetadata(kept)
        try await harness.store.saveMetadata(deleted)
        await harness.model.select(kept.id)
        await harness.model.select(deleted.id)

        #expect(SessionOpenings(defaults: harness.defaults).openedAt.keys.contains(deleted.id))

        await harness.model.deleteSession(deleted.id)
        let remembered = SessionOpenings(defaults: harness.defaults).openedAt
        #expect(remembered.keys.contains(kept.id))
        #expect(!remembered.keys.contains(deleted.id))
    }
}

@Test func aPageClosesWhenItsRowLeavesTheSidebar() async throws {
    try await withWorkspace { harness in
        let model = harness.model
        let empty = SidebarGroups(sessions: [], status: sampleStatus)

        model.showPage(.folder("/Users/me/Documents"))
        model.closePageIfGone(from: empty, statusKnown: false)
        #expect(model.page == nil)

        model.showPage(.branch("NS-9"))
        model.closePageIfGone(from: empty, statusKnown: false)
        #expect(model.page == .branch("NS-9"))
        model.closePageIfGone(from: empty, statusKnown: true)
        #expect(model.page == nil)

        model.showPage(.branch("NS-12"))
        model.closePageIfGone(from: empty, statusKnown: true)
        #expect(model.page == .branch("NS-12"))

        model.showPage(.archived)
        model.closePageIfGone(from: empty, statusKnown: true)
        #expect(model.page == .archived)
    }
}
