import AppKit
import Observation
import SwiftTerm

@Observable
final class PanelTerminals {
    typealias Environment = @Sendable () async -> [String: String]

    private(set) var all: [PanelTerminal] = []
    private var selection: [UUID: UUID] = [:]
    var isPanelOpen = false

    @ObservationIgnored private let shell: String
    @ObservationIgnored private let environment: Environment
    @ObservationIgnored private var quitting: (any NSObjectProtocol)?

    init(shell: String = ShellEnvironment.loginShell(),
         environment: @escaping Environment = { await ShellEnvironment.shared.resolve().variables },
         center: NotificationCenter = .default) {
        self.shell = shell
        self.environment = environment
        quitting = center.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.closeAll() }
        }
    }

    func terminals(of sessionID: UUID) -> [PanelTerminal] {
        all.filter { $0.sessionID == sessionID }
    }

    func isPanelShown(for sessionID: UUID) -> Bool {
        isPanelOpen && selected(in: sessionID) != nil
    }

    func selected(in sessionID: UUID) -> PanelTerminal? {
        let terminals = terminals(of: sessionID)
        return terminals.first { $0.id == selection[sessionID] } ?? terminals.last
    }

    func select(_ terminal: PanelTerminal) {
        guard selection[terminal.sessionID] != terminal.id else { return }
        selection[terminal.sessionID] = terminal.id
        terminal.wantsFocus = true
    }

    @discardableResult
    func open(for sessionID: UUID, in directory: URL) -> PanelTerminal {
        let name = URL(fileURLWithPath: shell).lastPathComponent
        let launch = PanelTerminal.Launch(executable: shell,
                                          environment: Terminal.getEnvironmentVariables() + ["SHELL=\(shell)"],
                                          execName: "-" + name,
                                          directory: directory)
        return add(PanelTerminal(sessionID: sessionID, kind: .free(shell: name), launch: launch, ended: removal))
    }

    @discardableResult
    func openConsole(for sessionID: UUID, branch: String, service: String,
                     session: String, in directory: URL) async -> PanelTerminal {
        let kind = PanelTerminal.Kind.console(branch: branch, service: service)
        let environment = await consoleEnvironment()
        if let open = terminals(of: sessionID).first(where: { $0.kind == kind }) {
            select(open)
            isPanelOpen = true
            return open
        }
        let launch = PanelTerminal.Launch(executable: "/bin/sh",
                                          arguments: ["-c", Self.attach, "sh", session, Self.notAttached],
                                          environment: environment,
                                          directory: directory)
        return add(PanelTerminal(sessionID: sessionID, kind: kind, launch: launch, ended: removal))
    }

    func togglePanel(for sessionID: UUID, in directory: URL) {
        if terminals(of: sessionID).isEmpty {
            open(for: sessionID, in: directory)
        } else {
            isPanelOpen.toggle()
            if isPanelOpen { selected(in: sessionID)?.wantsFocus = true }
        }
    }

    func close(_ terminal: PanelTerminal) {
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

    private static let attach = """
        tmux attach-session -t "=$1" && exit
        printf '\\r\\n%s\\r\\n' "$2"
        read -r _
        """

    private static let notAttached =
        "Este Serviço não tem uma sessão do ns para anexar. Inicie-o pelo Thalamus ou com ns start. Enter fecha."

    private var removal: (UUID) -> Void {
        { [weak self] id in self?.remove(id) }
    }

    private func add(_ terminal: PanelTerminal) -> PanelTerminal {
        all.append(terminal)
        select(terminal)
        isPanelOpen = true
        return terminal
    }

    private func consoleEnvironment() async -> [String] {
        var variables = await environment()
        variables["TMUX"] = nil
        variables["TMUX_PANE"] = nil
        for entry in Terminal.getEnvironmentVariables() {
            let pair = entry.split(separator: "=", maxSplits: 1).map(String.init)
            if pair.count == 2 { variables[pair[0]] = pair[1] }
        }
        return variables.map { "\($0.key)=\($0.value)" }
    }

    private func remove(_ id: UUID) {
        all.removeAll { $0.id == id }
    }
}
