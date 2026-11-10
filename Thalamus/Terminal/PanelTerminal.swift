import SwiftUI
import SwiftTerm

final class PanelTerminal: Identifiable {
    enum Kind: Equatable {
        case free(shell: String)
        case console(branch: String, service: String)
    }

    struct Launch {
        var executable: String
        var arguments: [String] = []
        var environment: [String]
        var execName: String?
        var directory: URL
    }

    let id = UUID()
    let row: SidebarRow
    let kind: Kind
    let view: LocalProcessTerminalView
    var wantsFocus = true
    private let watcher: ExitWatcher

    init(row: SidebarRow, kind: Kind, launch: Launch, ended: @escaping (UUID) -> Void) {
        self.row = row
        self.kind = kind
        view = LocalProcessTerminalView(frame: CGRect(x: 0, y: 0, width: 640, height: 220))
        watcher = ExitWatcher(id: id, ended: ended)
        view.processDelegate = watcher
        view.nativeBackgroundColor = NSColor(Theme.terminal)
        view.nativeForegroundColor = NSColor(Theme.textSecondary)
        view.caretColor = NSColor(Theme.textSecondary)
        view.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        view.startProcess(executable: launch.executable,
                          args: launch.arguments,
                          environment: launch.environment,
                          execName: launch.execName,
                          currentDirectory: launch.directory.path)
    }

    var title: String {
        switch kind {
        case .free(let shell): "Terminal livre · \(shell)"
        case .console(_, let service): "Console · \(service)"
        }
    }

    var isConsole: Bool {
        if case .console = kind { true } else { false }
    }

    var pid: pid_t { view.process.shellPid }

    func hangUp() {
        let pid = pid
        if view.process.running, pid > 0 { kill(pid, SIGHUP) }
    }
}

private final class ExitWatcher: LocalProcessTerminalViewDelegate {
    let id: UUID
    let ended: (UUID) -> Void

    init(id: UUID, ended: @escaping (UUID) -> Void) {
        self.id = id
        self.ended = ended
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) { ended(id) }
    func processFailedToStart(source: TerminalView, error: LocalProcessError) { ended(id) }
    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
}

extension NSEvent {
    var isForPanelTerminal: Bool { window?.firstResponder is TerminalView }
}
