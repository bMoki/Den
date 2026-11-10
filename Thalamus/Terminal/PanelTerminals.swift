import AppKit
import Observation
import SwiftTerm

@Observable
final class PanelTerminals {
    typealias Environment = @Sendable () async -> [String: String]

    private(set) var all: [PanelTerminal] = []
    private var selection: [SidebarRow: UUID] = [:]
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

    var rows: Set<SidebarRow> {
        Set(all.map(\.row))
    }

    func terminals(of row: SidebarRow) -> [PanelTerminal] {
        all.filter { $0.row == row }
    }

    func isPanelShown(for row: SidebarRow) -> Bool {
        isPanelOpen && row != .archived && selected(in: row) != nil
    }

    func selected(in row: SidebarRow) -> PanelTerminal? {
        let terminals = terminals(of: row)
        return terminals.first { $0.id == selection[row] } ?? terminals.last
    }

    func select(_ terminal: PanelTerminal) {
        guard selection[terminal.row] != terminal.id else { return }
        selection[terminal.row] = terminal.id
        terminal.wantsFocus = true
    }

    @discardableResult
    func open(for row: SidebarRow, in root: URL) -> PanelTerminal {
        let name = URL(fileURLWithPath: shell).lastPathComponent
        let launch = PanelTerminal.Launch(executable: shell,
                                          environment: Terminal.getEnvironmentVariables() + ["SHELL=\(shell)"]
                                              + NsConfigFolder.passedOn(ProcessInfo.processInfo.environment),
                                          execName: "-" + name,
                                          directory: root)
        return add(PanelTerminal(row: row, kind: .free(shell: name), launch: launch, ended: removal))
    }

    @discardableResult
    func openConsole(branch: String, service: String, session: String, in root: URL) async -> PanelTerminal {
        let row = SidebarRow.branch(branch)
        let kind = PanelTerminal.Kind.console(branch: branch, service: service)
        let environment = await consoleEnvironment()
        if let open = terminals(of: row).first(where: { $0.kind == kind }) {
            select(open)
            isPanelOpen = true
            return open
        }
        let launch = PanelTerminal.Launch(executable: "/bin/sh",
                                          arguments: ["-c", Self.attach, "sh", session, Self.notAttached],
                                          environment: environment,
                                          directory: root)
        return add(PanelTerminal(row: row, kind: kind, launch: launch, ended: removal))
    }

    func togglePanel(for row: SidebarRow, in root: URL) {
        if terminals(of: row).isEmpty {
            open(for: row, in: root)
        } else {
            isPanelOpen.toggle()
            if isPanelOpen { selected(in: row)?.wantsFocus = true }
        }
    }

    func close(_ terminal: PanelTerminal) {
        terminal.hangUp()
        remove(terminal.id)
    }

    func close(_ row: SidebarRow) {
        for terminal in terminals(of: row) { close(terminal) }
        selection[row] = nil
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
