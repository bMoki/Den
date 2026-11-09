import AppKit
import Foundation
import SwiftTerm
import Testing
@testable import Den

private func type(_ text: String, into terminal: PanelTerminal) {
    terminal.view.send(data: ArraySlice(Array(text.utf8)))
}

private func isAlive(_ pid: pid_t) -> Bool {
    pid > 0 && kill(pid, 0) == 0
}

@MainActor
@Test func aPanelTerminalOpensAShellInTheRowRoot() async throws {
    let folder = try makeTree([])
    let terminals = PanelTerminals(shell: "/bin/sh")
    let row = anyRow()

    let terminal = terminals.open(for: row, in: folder)
    type("pwd -P > here.txt\n", into: terminal)

    let here = folder.appending(path: "here.txt")
    #expect(await eventually { (try? String(contentsOf: here, encoding: .utf8))?.isEmpty == false })
    let reported = try String(contentsOf: here, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    #expect(URL(fileURLWithPath: reported).resolvingSymlinksInPath() == folder.resolvingSymlinksInPath())
    #expect(terminals.isPanelOpen)
    terminals.closeAll()
}

@MainActor
@Test func aRowCanHoldSeveralPanelTerminals() throws {
    let folder = try makeTree([])
    let terminals = PanelTerminals(shell: "/bin/sh")
    let row = anyRow()
    let other = anyRow()

    let first = terminals.open(for: row, in: folder)
    let second = terminals.open(for: row, in: folder)
    terminals.open(for: other, in: folder)

    #expect(terminals.terminals(of: row).map(\.id) == [first.id, second.id])
    #expect(terminals.selected(in: row)?.id == second.id)
    terminals.select(first)
    #expect(terminals.selected(in: row)?.id == first.id)
    terminals.closeAll()
}

@MainActor
@Test func closingATerminalEndsItsShell() async throws {
    let folder = try makeTree([])
    let terminals = PanelTerminals(shell: "/bin/sh")
    let row = anyRow()
    let kept = terminals.open(for: row, in: folder)
    let closed = terminals.open(for: row, in: folder)
    #expect(await eventually { isAlive(closed.pid) })
    let pid = closed.pid

    terminals.close(closed)

    #expect(await eventually { !isAlive(pid) })
    #expect(terminals.terminals(of: row).map(\.id) == [kept.id])
    #expect(terminals.selected(in: row)?.id == kept.id)
    terminals.closeAll()
}

@MainActor
@Test func quittingTheAppEndsEveryShell() async throws {
    let folder = try makeTree([])
    let center = NotificationCenter()
    let terminals = PanelTerminals(shell: "/bin/sh", center: center)
    let opened = [terminals.open(for: anyRow(), in: folder), terminals.open(for: anyRow(), in: folder)]
    #expect(await eventually { opened.allSatisfy { isAlive($0.pid) } })
    let pids = opened.map(\.pid)

    center.post(name: NSApplication.willTerminateNotification, object: nil)

    #expect(await eventually { pids.allSatisfy { !isAlive($0) } })
    #expect(terminals.all.isEmpty)
}

@MainActor
@Test func aShellThatExitsLeavesThePanel() async throws {
    let folder = try makeTree([])
    let terminals = PanelTerminals(shell: "/bin/sh")
    let row = anyRow()
    let terminal = terminals.open(for: row, in: folder)

    type("exit\n", into: terminal)

    #expect(await eventually { terminals.terminals(of: row).isEmpty })
}

@MainActor
@Test func theToggleOpensATerminalWhenTheRowHasNone() throws {
    let folder = try makeTree([])
    let terminals = PanelTerminals(shell: "/bin/sh")
    let row = anyRow()

    terminals.togglePanel(for: row, in: folder)
    #expect(terminals.isPanelOpen)
    #expect(terminals.terminals(of: row).count == 1)

    terminals.togglePanel(for: row, in: folder)
    #expect(!terminals.isPanelOpen)
    #expect(terminals.terminals(of: row).count == 1)

    terminals.togglePanel(for: row, in: folder)
    #expect(terminals.isPanelOpen)
    #expect(terminals.terminals(of: row).count == 1)
    terminals.closeAll()
}

@MainActor
@Test func closingARowEndsOnlyItsShells() async throws {
    let folder = try makeTree([])
    let terminals = PanelTerminals(shell: "/bin/sh")
    let row = anyRow()
    let closed = terminals.open(for: row, in: folder)
    let kept = terminals.open(for: anyRow(), in: folder)
    #expect(await eventually { isAlive(closed.pid) && isAlive(kept.pid) })
    let pid = closed.pid

    terminals.close(row)

    #expect(await eventually { !isAlive(pid) })
    #expect(terminals.all.map(\.id) == [kept.id])
    #expect(!terminals.isPanelShown(for: row))
    terminals.closeAll()
}

private func fakeTmux(in folder: URL) throws -> PanelTerminals {
    let script = folder.appending(path: "tmux")
    try """
        #!/bin/sh
        here=$(dirname "$0")
        printf '%s\\n' "$@" > "$here/tmux.args"
        [ "$3" = "=ns-ns-1-backend" ] || exit 1
        echo $$ > "$here/tmux.pid"
        exec cat > "$here/tmux.keys"
        """.write(to: script, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
    let path = folder.path + ":/usr/bin:/bin"
    return PanelTerminals(shell: "/bin/sh", environment: { ["PATH": path, "TMUX": "/tmp/outer,1,0"] })
}

private func contents(_ file: URL) -> String {
    (try? String(contentsOf: file, encoding: .utf8)) ?? ""
}

@MainActor
private func openAttachedConsole(_ terminals: PanelTerminals, in folder: URL) async -> PanelTerminal {
    let console = await terminals.openConsole(branch: "NS-1", service: "backend", session: "ns-ns-1-backend", in: folder)
    _ = await eventually { !contents(folder.appending(path: "tmux.pid")).isEmpty }
    return console
}

@MainActor
@Test func aConsoleAttachesToTheServiceSessionAndTakesTheKeyboard() async throws {
    let folder = try makeTree([])
    let terminals = try fakeTmux(in: folder)
    let row = SidebarRow.branch("NS-1")

    let console = await openAttachedConsole(terminals, in: folder)
    #expect(console.title == "Console · backend")
    #expect(contents(folder.appending(path: "tmux.args")) == "attach-session\n-t\n=ns-ns-1-backend\n")

    type("r\n", into: console)
    #expect(await eventually { contents(folder.appending(path: "tmux.keys")) == "r\n" })

    let again = await terminals.openConsole(branch: "NS-1", service: "backend", session: "ns-ns-1-backend", in: folder)
    #expect(again.id == console.id)
    #expect(terminals.terminals(of: row).count == 1)
    terminals.closeAll()
}

@MainActor
@Test func closingAConsoleOnlyDetachesItsClient() async throws {
    let folder = try makeTree([])
    let terminals = try fakeTmux(in: folder)
    let row = SidebarRow.branch("NS-1")
    let console = await openAttachedConsole(terminals, in: folder)
    let pidFile = folder.appending(path: "tmux.pid")
    let client = try #require(pid_t(contents(pidFile).trimmingCharacters(in: .whitespacesAndNewlines)))

    terminals.close(console)

    #expect(await eventually { !isAlive(client) })
    #expect(terminals.terminals(of: row).isEmpty)
}

@MainActor
@Test func aConsoleWithoutASessionSaysSoAndStaysUntilEnter() async throws {
    let folder = try makeTree([])
    let terminals = try fakeTmux(in: folder)
    let row = SidebarRow.branch("NS-1")

    let console = await terminals.openConsole(branch: "NS-1", service: "frontend", session: "ns-ns-1-frontend", in: folder)
    #expect(await eventually { contents(folder.appending(path: "tmux.args")).contains("=ns-ns-1-frontend") })
    try await Task.sleep(for: .milliseconds(300))
    #expect(terminals.terminals(of: row).map(\.id) == [console.id])

    type("\n", into: console)
    #expect(await eventually { terminals.terminals(of: row).isEmpty })
}

@MainActor
@Test func removingABranchFindsOnlyItsRowsToClose() {
    let rows: Set<SidebarRow> = [.branch("NS-12"), .branch("NS-1234"), .folder("/code/project"), .baseRepo("backend")]

    #expect(sampleStatus.removed(among: rows) == [.branch("NS-1234")])
}
