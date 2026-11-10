import Foundation
import Testing
@testable import Thalamus

private let day: TimeInterval = 86_400

private let datedStatus = NsStatus(
    worktreesDir: "/dev/worktrees",
    baseRepos: sampleStatus.baseRepos,
    branches: [.init(branch: "NS-12", path: "/dev/worktrees/NS-12", createdAt: Date(timeIntervalSince1970: day)),
               .init(branch: "NS-123", path: "/dev/worktrees/NS-123", createdAt: Date(timeIntervalSince1970: 2 * day)),
               .init(branch: "NS-5", path: "/dev/worktrees/NS-5")])

private func favorite(_ folder: SidebarGroups.Folder?) throws -> SidebarFavorite {
    try #require(folder).favorite
}

private func layout(favoriting folders: [SidebarGroups.Folder?], order: SidebarOrder = .name) throws -> SidebarLayout {
    SidebarLayout(favorites: Set(try folders.map(favorite)), order: order)
}

@Test func aFavoriteLeavesItsGroupForTheFavoritesKeepingItsHeader() throws {
    let plain = SidebarGroups(sessions: [summary("loose", in: "/Users/me/Documents")], status: datedStatus)
    let layout = try layout(favoriting: [plain.branches[1], plain.baseRepos.last, plain.otherFolders.first])

    let groups = SidebarGroups(sessions: [summary("loose", in: "/Users/me/Documents")], status: datedStatus,
                               layout: layout)

    #expect(groups.favorites.map(\.name) == ["Documents", "frontend", "NS-12"])
    #expect(groups.favorites.map(\.kind) == [.folder, .baseRepo, .branch])
    #expect(groups.favorites.map(\.id) == [plain.otherFolders[0].id, plain.baseRepos[1].id, plain.branches[1].id])
    #expect(!groups.branches.map(\.name).contains("NS-12"))
    #expect(groups.baseRepos.map(\.name) == ["backend"])
    #expect(groups.otherFolders.isEmpty)
}

@Test func withoutFavoritesThereIsNoFavoritesGroup() {
    #expect(SidebarGroups(sessions: [], status: datedStatus).favorites.isEmpty)
}

@Test func aFavoriteFolderShowsOnlyWhileItHasSessionsLikeInOtherFolders() throws {
    let before = SidebarGroups(sessions: [summary("loose", in: "/Users/me/Documents")], status: datedStatus)
    let layout = try layout(favoriting: [before.otherFolders.first])

    #expect(SidebarGroups(sessions: [], status: datedStatus, layout: layout).favorites.isEmpty)
    #expect(SidebarGroups(sessions: [summary("loose", in: "/Users/me/Documents")], status: datedStatus,
                          search: "nothing", layout: layout).favorites.isEmpty)
    #expect(SidebarGroups(sessions: [summary("again", in: "/Users/me/Documents")], status: datedStatus,
                          layout: layout).favorites.map(\.name) == ["Documents"])
}

@Test func branchesSortByNameOrNewestFirst() {
    let byName = SidebarGroups(sessions: [], status: datedStatus)
    let byRecent = SidebarGroups(sessions: [], status: datedStatus, layout: SidebarLayout(order: .recent))

    #expect(byName.branches.map(\.name) == ["NS-5", "NS-12", "NS-123"])
    #expect(byRecent.branches.map(\.name) == ["NS-123", "NS-12", "NS-5"])
}

@Test func favoritesFollowTheOrderWithBranchesFirstWhenNewestFirst() throws {
    let plain = SidebarGroups(sessions: [summary("loose", in: "/Users/me/Documents")], status: datedStatus)
    let favorites = [plain.branches[1], plain.branches[2], plain.baseRepos[0], plain.otherFolders[0]]

    let byName = SidebarGroups(sessions: [summary("loose", in: "/Users/me/Documents")], status: datedStatus,
                               layout: try layout(favoriting: favorites))
    let byRecent = SidebarGroups(sessions: [summary("loose", in: "/Users/me/Documents")], status: datedStatus,
                                 layout: try layout(favoriting: favorites, order: .recent))

    #expect(byName.favorites.map(\.name) == ["backend", "Documents", "NS-12", "NS-123"])
    #expect(byRecent.favorites.map(\.name) == ["NS-123", "NS-12", "backend", "Documents"])
}

@Test func searchFiltersTheFavoritesLikeTheOtherGroups() throws {
    let plain = SidebarGroups(sessions: [], status: datedStatus)
    let layout = try layout(favoriting: [plain.branches[1], plain.baseRepos[0]])
    var status = datedStatus
    status.branches[0].nickname = "Agenda"

    let groups = SidebarGroups(sessions: [], status: status, search: "agenda", layout: layout)

    #expect(groups.favorites.map(\.name) == ["NS-12"])
    #expect(groups.branches.isEmpty)
}

@Test func aRemovedBranchStopsBeingAFavoriteAndARecreatedOneIsBornWithout() throws {
    let plain = SidebarGroups(sessions: [], status: datedStatus)
    let layout = try layout(favoriting: [plain.branches[1], plain.baseRepos[0]])
    var removed = datedStatus
    removed.branches.remove(at: 0)
    var recreated = datedStatus
    recreated.branches[0].createdAt = Date(timeIntervalSince1970: 3 * day)

    #expect(layout.pruned(by: datedStatus) == layout)
    #expect(layout.pruned(by: removed).favorites == [plain.baseRepos[0].favorite])
    #expect(SidebarGroups(sessions: [], status: recreated, layout: layout).favorites.map(\.name) == ["backend"])
}

@Test func aBranchFavoritedBeforeNsToldItsCreationLearnsIt() {
    let old = SidebarLayout(favorites: [SidebarFavorite(kind: .branch, path: "/dev/worktrees/NS-12", createdAt: nil)])

    let learned = old.pruned(by: datedStatus)

    #expect(learned.favorites == [SidebarFavorite(kind: .branch, path: "/dev/worktrees/NS-12",
                                                  createdAt: Date(timeIntervalSince1970: day))])
}

@Test func favoritesAndTheOrderSurviveReopeningTheApp() async throws {
    try await withWorkspace { harness in
        let folder = try #require(SidebarGroups(sessions: [], status: datedStatus).branches.first)

        harness.model.layout.toggle(folder.favorite)
        harness.model.layout.order = .recent

        let reopened = SidebarLayout(defaults: harness.defaults)
        #expect(reopened.favorites == [folder.favorite])
        #expect(reopened.order == .recent)

        harness.model.layout.toggle(folder.favorite)
        #expect(!harness.model.layout.isFavorite(folder.favorite))
        #expect(SidebarLayout(defaults: harness.defaults).favorites.isEmpty)
    }
}

@Test func theOrderIsNameUntilChosen() async throws {
    try await withWorkspace { harness in
        #expect(harness.model.layout.order == .name)
        #expect(harness.model.layout.favorites.isEmpty)
    }
}

@Test func aCollapsedGroupShowsOnlyTheRowInFocus() {
    let branches = SidebarGroups(sessions: [], status: datedStatus).branches
    let expanded = SidebarLayout()
    let collapsed = SidebarLayout(collapsed: [.branches])

    #expect(expanded.shown(branches, in: .branches, focus: .branch("NS-12"), searching: false) == branches)
    #expect(collapsed.shown(branches, in: .branches, focus: .branch("NS-12"), searching: false).map(\.name)
        == ["NS-12"])
    #expect(collapsed.shown(branches, in: .branches, focus: .baseRepo("backend"), searching: false).isEmpty)
    #expect(collapsed.shown(branches, in: .branches, focus: nil, searching: false).isEmpty)
    #expect(collapsed.shown(branches, in: .favorites, focus: nil, searching: false) == branches)
}

@Test func searchingShowsEveryGroupWithoutForgettingWhichAreCollapsed() {
    let branches = SidebarGroups(sessions: [], status: datedStatus).branches
    let collapsed = SidebarLayout(collapsed: [.branches])

    #expect(collapsed.isExpanded(.branches, searching: true))
    #expect(collapsed.shown(branches, in: .branches, focus: nil, searching: true) == branches)
    #expect(!collapsed.isExpanded(.branches, searching: false))
    #expect(collapsed.collapsed == [.branches])
}

@Test func collapsedGroupsSurviveReopeningTheApp() async throws {
    try await withWorkspace { harness in
        #expect(harness.model.layout.collapsed.isEmpty)

        harness.model.layout.toggleCollapsed(.branches)
        harness.model.layout.toggleCollapsed(.favorites)
        #expect(SidebarLayout(defaults: harness.defaults).collapsed == [.branches, .favorites])

        harness.model.layout.toggleCollapsed(.branches)
        #expect(SidebarLayout(defaults: harness.defaults).collapsed == [.favorites])
    }
}

@Test func aLayoutSavedBeforeGroupsCollapsedKeepsItsFavoritesAndOrder() throws {
    let saved = Data(#"{"favorites":[{"kind":"baseRepo","path":"/dev/backend"}],"order":"recent"}"#.utf8)

    let layout = try JSONDecoder().decode(SidebarLayout.self, from: saved)

    #expect(layout.favorites == [SidebarFavorite(kind: .baseRepo, path: "/dev/backend")])
    #expect(layout.order == .recent)
    #expect(layout.collapsed.isEmpty)
}
