import Foundation
import Testing
@testable import Den

let sampleStatus = NsStatus(
    baseRepos: [.init(repo: "backend", path: "/dev/scalemed-backend"),
                .init(repo: "frontend", path: "/dev/frontend")],
    branches: [.init(branch: "NS-12", path: "/dev/worktrees/NS-12"),
               .init(branch: "NS-123", path: "/dev/worktrees/NS-123")])

@Test func aSessionAtTheRootOfABranchBelongsToIt() {
    #expect(sampleStatus.place(of: URL(fileURLWithPath: "/dev/worktrees/NS-12")) == .branch("NS-12"))
}

@Test func aFolderOpenedInsideABranchStillBelongsToIt() {
    let inside = URL(fileURLWithPath: "/dev/worktrees/NS-123/backend/src/")
    #expect(sampleStatus.place(of: inside) == .branch("NS-123"))
}

@Test func aBranchNameThatPrefixesAnotherDoesNotCaptureIt() {
    #expect(sampleStatus.place(of: URL(fileURLWithPath: "/dev/worktrees/NS-1234")) == .elsewhere)
}

@Test func aSessionInABaseRepoBelongsToThatRepo() {
    #expect(sampleStatus.place(of: URL(fileURLWithPath: "/dev/frontend/src")) == .baseRepo("frontend"))
}

@Test func anyOtherFolderIsElsewhere() {
    #expect(sampleStatus.place(of: URL(fileURLWithPath: "/Users/me/Documents")) == .elsewhere)
    #expect(sampleStatus.place(of: URL(fileURLWithPath: "/dev/worktrees/removed")) == .elsewhere)
}

@Test func theStatusDecodesFromWhatNsRpcSends() throws {
    let json = """
        {"baseRepos":[{"repo":"backend","path":"/dev/b"}],
         "branches":[{"branch":"NS-1","slug":"ns-1","path":"/dev/worktrees/NS-1",
                      "ports":{"db":5438,"backend":8084,"frontend":3015,"manager":3021},
                      "services":{"db":"rodando","backend":"iniciando","frontend":"falhou",
                                  "manager":"parado","reportServer":null}}]}
        """
    let status = try JSONDecoder().decode(NsStatus.self, from: Data(json.utf8))
    #expect(status.baseRepos == [.init(repo: "backend", path: "/dev/b")])
    #expect(status.branches == [.init(
        branch: "NS-1", path: "/dev/worktrees/NS-1",
        services: [.init(id: "backend", state: .iniciando, port: 8084),
                   .init(id: "frontend", state: .falhou, port: 3015),
                   .init(id: "manager", state: .parado, port: 3021)],
        database: .rodando, databasePort: 5438)])
}

@Test func aBranchWithoutServiceStatesStillDecodes() throws {
    let json = #"{"baseRepos":[],"branches":[{"branch":"NS-1","path":"/w/NS-1","services":{"db":true}}]}"#
    let status = try JSONDecoder().decode(NsStatus.self, from: Data(json.utf8))
    #expect(status.branches == [.init(branch: "NS-1", path: "/w/NS-1")])
}
