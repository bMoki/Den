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
                    .padding(.leading, Theme.space(.s8))
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
                Theme.image(.add)
                    .font(Theme.font(.caption, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .iconLabel(size: .s22)
            }
            .buttonStyle(.thalamusGhost(radius: .r5))
            .padding(.leading, Theme.space(.s4))
            .help("Novo Terminal livre")
            .accessibilityLabel("Novo Terminal livre")
            Spacer(minLength: Theme.space(.s8))
            Text(current.isConsole ? "Fechar o Console não para o Serviço"
                : "Terminais livres se encerram quando o Thalamus fecha")
                .font(Theme.font(.captionPlus))
                .foregroundStyle(Theme.textFaint)
                .lineLimit(1)
            Button {
                terminals.isPanelOpen = false
            } label: {
                Theme.image(.expanded)
                    .font(Theme.font(.label, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .iconLabel(size: .s22)
            }
            .buttonStyle(.thalamusGhost(radius: .r5))
            .padding(.horizontal, Theme.space(.s6))
            .help("Ocultar painel")
            .accessibilityLabel("Ocultar painel")
        }
        .padding(.leading, Theme.space(.s4))
        .frame(height: Theme.size(.s34))
        .background(Theme.panel)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: Theme.line(.thin)) }
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
            Theme.image(.toggleTerminals)
                .font(Theme.font(.large))
                .foregroundStyle(isShown ? Theme.text : Theme.textSecondary)
                .iconLabel(size: .s32)
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
        HStack(spacing: Theme.space(.s7)) {
            if let console {
                ServiceIndicator(.service(console.id), state: console.state)
            } else {
                Theme.image(.terminal)
                    .font(Theme.font(.caption))
            }
            Text(title)
                .lineLimit(1)
            Button(action: close) {
                Theme.image(.close)
                    .font(Theme.font(.tinyPlus, weight: .bold))
                    .frame(width: Theme.size(.s16), height: Theme.size(.s16))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.thalamusGhost(radius: .r4))
            .opacity(isSelected || hovering ? 1 : 0)
            .help(console == nil ? "Fechar Terminal livre" : "Fechar Console")
            .accessibilityLabel("Fechar \(title)")
        }
        .font(Theme.font(.small))
        .foregroundStyle(isSelected ? Theme.text : hovering ? Theme.textSecondary : Theme.textTertiary)
        .padding(.leading, Theme.space(.s10))
        .padding(.trailing, Theme.space(.s8))
        .frame(maxHeight: .infinity)
        .background(isSelected ? Theme.terminal : .clear)
        .overlay(alignment: .top) {
            if isSelected { Rectangle().fill(Theme.accent).frame(height: Theme.size(.s2)) }
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
