import AppKit
import Foundation
import SwiftTerm
import Testing
@testable import Den

private func type(_ text: String, into terminal: FreeTerminal) {
    terminal.view.send(data: ArraySlice(Array(text.utf8)))
}

private func isAlive(_ pid: pid_t) -> Bool {
    pid > 0 && kill(pid, 0) == 0
}

@MainActor
@Test func aFreeTerminalOpensAShellInTheSessionFolder() async throws {
    let folder = try makeTree([])
    let terminals = FreeTerminals(shell: "/bin/sh")
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
@Test func aSessionCanHoldSeveralFreeTerminals() throws {
    let folder = try makeTree([])
    let terminals = FreeTerminals(shell: "/bin/sh")
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
    let terminals = FreeTerminals(shell: "/bin/sh")
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
    let terminals = FreeTerminals(shell: "/bin/sh", center: center)
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
    let terminals = FreeTerminals(shell: "/bin/sh")
    let session = UUID()
    let terminal = terminals.open(for: session, in: folder)

    type("exit\n", into: terminal)

    #expect(await eventually { terminals.terminals(of: session).isEmpty })
}

@MainActor
@Test func theToggleOpensATerminalWhenTheSessionHasNone() throws {
    let folder = try makeTree([])
    let terminals = FreeTerminals(shell: "/bin/sh")
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
    let terminals = FreeTerminals(shell: "/bin/sh")
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
