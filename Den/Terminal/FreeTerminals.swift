import AppKit
import Observation

@Observable
final class FreeTerminals {
    private(set) var all: [FreeTerminal] = []
    private var selection: [UUID: UUID] = [:]
    var isPanelOpen = false

    @ObservationIgnored private let shell: String
    @ObservationIgnored private var quitting: (any NSObjectProtocol)?

    init(shell: String = ShellEnvironment.loginShell(), center: NotificationCenter = .default) {
        self.shell = shell
        quitting = center.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.closeAll() }
        }
    }

    func terminals(of sessionID: UUID) -> [FreeTerminal] {
        all.filter { $0.sessionID == sessionID }
    }

    func isPanelShown(for sessionID: UUID) -> Bool {
        isPanelOpen && selected(in: sessionID) != nil
    }

    func selected(in sessionID: UUID) -> FreeTerminal? {
        let terminals = terminals(of: sessionID)
        return terminals.first { $0.id == selection[sessionID] } ?? terminals.last
    }

    func select(_ terminal: FreeTerminal) {
        guard selection[terminal.sessionID] != terminal.id else { return }
        selection[terminal.sessionID] = terminal.id
        terminal.wantsFocus = true
    }

    @discardableResult
    func open(for sessionID: UUID, in directory: URL) -> FreeTerminal {
        let terminal = FreeTerminal(sessionID: sessionID, directory: directory, shell: shell) { [weak self] id in
            self?.remove(id)
        }
        all.append(terminal)
        select(terminal)
        isPanelOpen = true
        return terminal
    }

    func togglePanel(for sessionID: UUID, in directory: URL) {
        if terminals(of: sessionID).isEmpty {
            open(for: sessionID, in: directory)
        } else {
            isPanelOpen.toggle()
            if isPanelOpen { selected(in: sessionID)?.wantsFocus = true }
        }
    }

    func close(_ terminal: FreeTerminal) {
        terminal.hangUp()
        remove(terminal.id)
    }

    func close(sessionID: UUID) {
        for terminal in terminals(of: sessionID) { close(terminal) }
        selection[sessionID] = nil
    }

    func closeAll() {
        for terminal in all { terminal.hangUp() }
        all.removeAll()
        selection.removeAll()
    }

    private func remove(_ id: UUID) {
        all.removeAll { $0.id == id }
    }
}
