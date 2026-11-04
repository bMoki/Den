import SwiftUI
import SwiftTerm

final class FreeTerminal: Identifiable {
    let id = UUID()
    let sessionID: UUID
    let title: String
    let view: LocalProcessTerminalView
    var wantsFocus = true
    private let watcher: ExitWatcher

    init(sessionID: UUID, directory: URL, shell: String, ended: @escaping (UUID) -> Void) {
        self.sessionID = sessionID
        let name = URL(fileURLWithPath: shell).lastPathComponent
        title = name
        view = LocalProcessTerminalView(frame: CGRect(x: 0, y: 0, width: 640, height: 220))
        watcher = ExitWatcher(id: id, ended: ended)
        view.processDelegate = watcher
        view.nativeBackgroundColor = NSColor(Theme.terminal)
        view.nativeForegroundColor = NSColor(Theme.textSecondary)
        view.caretColor = NSColor(Theme.textSecondary)
        view.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        view.startProcess(executable: shell,
                          environment: Terminal.getEnvironmentVariables() + ["SHELL=\(shell)"],
                          execName: "-" + name,
                          currentDirectory: directory.path)
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
    var isForFreeTerminal: Bool { window?.firstResponder is TerminalView }
}
