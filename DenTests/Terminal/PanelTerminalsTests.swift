import AppKit
import Foundation
import HarnessCore
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
@Test func aPanelTerminalOpensAShellInTheSessionFolder() async throws {
    let folder = try makeTree([])
    let terminals = PanelTerminals(shell: "/bin/sh")
    let session = UUID()

    let terminal = terminals.open(for: session, in: folder)
    type("pwd -P > here.txt\n", into: terminal)

    let here = folder.appending(path: "here.txt")
    #expect(await eventually { (try? String(contentsOf: here, encoding: .utf8))?.isEmpty == false })
    let reported = try String(contentsOf: here, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
    #expect(URL(fileURLWithPath: reported).resolvingSymlinksInPath() == folder.resolvingSymlinksInPath())
    #expect(terminals.isPanelOpen)
    terminals.closeAll()
}

@MainActor
@Test func aSessionCanHoldSeveralPanelTerminals() throws {
    let folder = try makeTree([])
    let terminals = PanelTerminals(shell: "/bin/sh")
    let session = UUID()
    let other = UUID()

    let first = terminals.open(for: session, in: folder)
    let second = terminals.open(for: session, in: folder)
    terminals.open(for: other, in: folder)

    #expect(terminals.terminals(of: session).map(\.id) == [first.id, second.id])
    #expect(terminals.selected(in: session)?.id == second.id)
    terminals.select(first)
    #expect(terminals.selected(in: session)?.id == first.id)
    terminals.closeAll()
}

@MainActor
@Test func closingATerminalEndsItsShell() async throws {
    let folder = try makeTree([])
    let terminals = PanelTerminals(shell: "/bin/sh")
    let session = UUID()
    let kept = terminals.open(for: session, in: folder)
    let closed = terminals.open(for: session, in: folder)
    #expect(await eventually { isAlive(closed.pid) })
    let pid = closed.pid

    terminals.close(closed)

    #expect(await eventually { !isAlive(pid) })
    #expect(terminals.terminals(of: session).map(\.id) == [kept.id])
    #expect(terminals.selected(in: session)?.id == kept.id)
    terminals.closeAll()
}

@MainActor
@Test func quittingTheAppEndsEveryShell() async throws {
    let folder = try makeTree([])
    let center = NotificationCenter()
    let terminals = PanelTerminals(shell: "/bin/sh", center: center)
    let opened = [terminals.open(for: UUID(), in: folder), terminals.open(for: UUID(), in: folder)]
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
    let session = UUID()
    let terminal = terminals.open(for: session, in: folder)

    type("exit\n", into: terminal)

    #expect(await eventually { terminals.terminals(of: session).isEmpty })
}

@MainActor
@Test func theToggleOpensATerminalWhenTheSessionHasNone() throws {
    let folder = try makeTree([])
    let terminals = PanelTerminals(shell: "/bin/sh")
    let session = UUID()

    terminals.togglePanel(for: session, in: folder)
    #expect(terminals.isPanelOpen)
    #expect(terminals.terminals(of: session).count == 1)

    terminals.togglePanel(for: session, in: folder)
    #expect(!terminals.isPanelOpen)
    #expect(terminals.terminals(of: session).count == 1)

    terminals.togglePanel(for: session, in: folder)
    #expect(terminals.isPanelOpen)
    #expect(terminals.terminals(of: session).count == 1)
    terminals.closeAll()
}

@MainActor
@Test func deletingASessionEndsOnlyItsShells() async throws {
    let folder = try makeTree([])
    let terminals = PanelTerminals(shell: "/bin/sh")
    let session = UUID()
    let deleted = terminals.open(for: session, in: folder)
    let kept = terminals.open(for: UUID(), in: folder)
    #expect(await eventually { isAlive(deleted.pid) && isAlive(kept.pid) })
    let pid = deleted.pid

    terminals.close(sessionID: session)

    #expect(await eventually { !isAlive(pid) })
    #expect(terminals.all.map(\.id) == [kept.id])
    #expect(!terminals.isPanelShown(for: session))
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
private func openAttachedConsole(_ terminals: PanelTerminals, for session: UUID, in folder: URL) async -> PanelTerminal {
    let console = await terminals.openConsole(for: session, branch: "NS-1", service: "backend",
                                              session: "ns-ns-1-backend", in: folder)
    _ = await eventually { !contents(folder.appending(path: "tmux.pid")).isEmpty }
    return console
}

@MainActor
@Test func aConsoleAttachesToTheServiceSessionAndTakesTheKeyboard() async throws {
    let folder = try makeTree([])
    let terminals = try fakeTmux(in: folder)
    let session = UUID()

    let console = await openAttachedConsole(terminals, for: session, in: folder)
    #expect(console.title == "Console · backend")
    #expect(contents(folder.appending(path: "tmux.args")) == "attach-session\n-t\n=ns-ns-1-backend\n")

    type("r\n", into: console)
    #expect(await eventually { contents(folder.appending(path: "tmux.keys")) == "r\n" })

    let again = await terminals.openConsole(for: session, branch: "NS-1", service: "backend",
                                            session: "ns-ns-1-backend", in: folder)
    #expect(again.id == console.id)
    #expect(terminals.terminals(of: session).count == 1)
    terminals.closeAll()
}

@MainActor
@Test func closingAConsoleOnlyDetachesItsClient() async throws {
    let folder = try makeTree([])
    let terminals = try fakeTmux(in: folder)
    let session = UUID()
    let console = await openAttachedConsole(terminals, for: session, in: folder)
    let pidFile = folder.appending(path: "tmux.pid")
    let client = try #require(pid_t(contents(pidFile).trimmingCharacters(in: .whitespacesAndNewlines)))

    terminals.close(console)

    #expect(await eventually { !isAlive(client) })
    #expect(terminals.terminals(of: session).isEmpty)
}

@MainActor
@Test func aConsoleWithoutASessionSaysSoAndStaysUntilEnter() async throws {
    let folder = try makeTree([])
    let terminals = try fakeTmux(in: folder)
    let session = UUID()

    let console = await terminals.openConsole(for: session, branch: "NS-1", service: "frontend",
                                              session: "ns-ns-1-frontend", in: folder)
    #expect(await eventually { contents(folder.appending(path: "tmux.args")).contains("=ns-ns-1-frontend") })
    try await Task.sleep(for: .milliseconds(300))
    #expect(terminals.terminals(of: session).map(\.id) == [console.id])

    type("\n", into: console)
    #expect(await eventually { terminals.terminals(of: session).isEmpty })
}

@MainActor
@Test func archivingASessionEndsItsShells() async throws {
    let folder = try makeTree([])
    let terminals = PanelTerminals(shell: "/bin/sh")
    let archived = summary("gone", in: "/dev/worktrees/NS-1234")
    let active = summary("here", in: "/dev/worktrees/NS-12")
    let ended = terminals.open(for: archived.id, in: folder)
    let kept = terminals.open(for: active.id, in: folder)
    #expect(await eventually { isAlive(ended.pid) && isAlive(kept.pid) })
    let pid = ended.pid

    SidebarGroups(sessions: [archived, active], status: sampleStatus).archived.forEach { terminals.close(sessionID: $0.id) }

    #expect(await eventually { !isAlive(pid) })
    #expect(terminals.all.map(\.id) == [kept.id])
    terminals.closeAll()
}
