import SwiftUI
import SwiftTerm

struct TerminalPanel: View {
    let row: SidebarRow
    let root: URL

    @Environment(PanelTerminals.self) private var terminals
    @Environment(NsWorkspace.self) private var ns
    @AppStorage(PreferenceKey.named("terminalPanelHeight")) private var height: Double = 220

    var body: some View {
        if terminals.isPanelShown(for: row), let current = terminals.selected(in: row) {
            VStack(spacing: 0) {
                ResizeHandle(height: $height, range: 120...640)
                tabs(terminals.terminals(of: row), current: current)
                TerminalHost(terminal: current)
                    .id(current.id)
                    .padding(.leading, 8)
                    .background(Theme.terminal)
            }
            .frame(height: height)
            .background(Theme.terminal)
        }
    }

    private func tabs(_ open: [PanelTerminal], current: PanelTerminal) -> some View {
        HStack(spacing: 0) {
            ForEach(open) { terminal in
                TerminalTab(title: terminal.title,
                            console: console(of: terminal),
                            isSelected: terminal.id == current.id,
                            select: { terminals.select(terminal) },
                            close: { terminals.close(terminal) })
            }
            Button {
                terminals.open(for: row, in: root)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .iconLabel(size: 22)
            }
            .buttonStyle(.thalamusGhost(radius: 5))
            .padding(.leading, 4)
            .help("Novo Terminal livre")
            .accessibilityLabel("Novo Terminal livre")
            Spacer(minLength: 8)
            Text(current.isConsole ? "Fechar o Console não para o Serviço"
                : "Terminais livres se encerram quando o Thalamus fecha")
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.textFaint)
                .lineLimit(1)
            Button {
                terminals.isPanelOpen = false
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .iconLabel(size: 22)
            }
            .buttonStyle(.thalamusGhost(radius: 5))
            .padding(.horizontal, 6)
            .help("Ocultar painel")
            .accessibilityLabel("Ocultar painel")
        }
        .padding(.leading, 4)
        .frame(height: 34)
        .background(Theme.panel)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }

    private func console(of terminal: PanelTerminal) -> NsStatus.Service? {
        guard case .console(let branch, let service) = terminal.kind else { return nil }
        return ns.branch(named: branch)?.services.first { $0.id == service } ?? NsStatus.Service(id: service, state: .parado)
    }
}

struct TerminalToggle: View {
    let row: SidebarRow
    let root: URL

    @Environment(PanelTerminals.self) private var terminals

    var body: some View {
        Button(action: toggle) {
            Image(systemName: "rectangle.bottomthird.inset.filled")
                .font(.system(size: 14))
                .foregroundStyle(isShown ? Theme.text : Theme.textSecondary)
                .iconLabel(size: 32)
        }
        .buttonStyle(ThalamusButtonStyle(kind: .secondary))
        .disabled(isArchived)
        .help(help)
        .accessibilityLabel(isShown ? "Ocultar Terminais livres" : "Mostrar Terminais livres")
        .accessibilityHint(isArchived ? Self.archivedFolderReason : "")
        .onKeyboardShortcut("`", modifiers: .control) { toggle() }
    }

    private static let archivedFolderReason = "Sessão arquivada: a pasta desta Sessão não existe mais."

    private var isArchived: Bool { row == .archived }

    private var isShown: Bool { terminals.isPanelShown(for: row) }

    private var help: String {
        if isArchived { return "Terminal livre indisponível. \(Self.archivedFolderReason)" }
        return isShown ? "Ocultar Terminais livres (⌃`)" : "Terminal livre (⌃`)"
    }

    private func toggle() {
        guard !isArchived else { return }
        terminals.togglePanel(for: row, in: root)
    }
}

private struct TerminalTab: View {
    let title: String
    let console: NsStatus.Service?
    let isSelected: Bool
    var select: () -> Void
    var close: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 7) {
            if let console {
                ServiceIndicator(.service(console.id), state: console.state)
            } else {
                Image(systemName: "terminal")
                    .font(.system(size: 11))
            }
            Text(title)
                .lineLimit(1)
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 8.5, weight: .bold))
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.thalamusGhost(radius: 4))
            .opacity(isSelected || hovering ? 1 : 0)
            .help(console == nil ? "Fechar Terminal livre" : "Fechar Console")
            .accessibilityLabel("Fechar \(title)")
        }
        .font(.system(size: 12))
        .foregroundStyle(isSelected ? Theme.text : hovering ? Theme.textSecondary : Theme.textTertiary)
        .padding(.leading, 10)
        .padding(.trailing, 8)
        .frame(maxHeight: .infinity)
        .background(isSelected ? Theme.terminal : .clear)
        .overlay(alignment: .top) {
            if isSelected { Rectangle().fill(Theme.accent).frame(height: 2) }
        }
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(perform: select)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct TerminalHost: NSViewRepresentable {
    let terminal: PanelTerminal

    func makeNSView(context: Context) -> HostView {
        let host = HostView()
        host.show(terminal)
        return host
    }

    func updateNSView(_ host: HostView, context: Context) {
        host.show(terminal)
    }

    final class HostView: NSView {
        private var terminal: PanelTerminal?

        func show(_ terminal: PanelTerminal) {
            self.terminal = terminal
            if terminal.view.superview !== self {
                terminal.view.removeFromSuperview()
                terminal.view.frame = bounds
                terminal.view.autoresizingMask = [.width, .height]
                addSubview(terminal.view)
            }
            focusIfWanted()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            focusIfWanted()
        }

        private func focusIfWanted() {
            guard let terminal, terminal.wantsFocus, let window else { return }
            terminal.wantsFocus = false
            window.makeFirstResponder(terminal.view)
        }
    }
}
