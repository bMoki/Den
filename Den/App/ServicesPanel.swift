import SwiftUI

struct ServicesPanel: View {
    let branch: String
    let sessionID: UUID
    let directory: URL

    @Environment(NsWorkspace.self) private var ns
    @Environment(PanelTerminals.self) private var terminals

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let status = ns.branch(named: branch) {
                    branchCard(status)
                    if !status.services.isEmpty {
                        sectionTitle("Serviços")
                        card {
                            ForEach(Array(status.services.enumerated()), id: \.element.id) { index, service in
                                VStack(spacing: 0) {
                                    row(name: service.id, detail: service.port.map { ":\($0)" },
                                        state: service.state, isFirst: index == 0) {
                                        serviceActions(service)
                                    }
                                    if service.state == .falhou {
                                        errorLine(service)
                                    }
                                }
                            }
                        }
                        sectionTitle("Banco")
                        card {
                            row(name: "postgres", detail: status.databasePort.map { ":\($0)" },
                                state: status.database, isDatabase: true, isFirst: true) {
                                iconAction("arrow.up.forward.app", title: BranchActionTitle.openDatabase, perform: openDatabase)
                                    .disabled(ns.activity[branch] != nil)
                            }
                            .denContextMenu([
                                DenMenuSection(id: "database", items: [
                                    DenMenuItem(id: "open", title: BranchActionTitle.openDatabase,
                                                isEnabled: ns.activity[branch] == nil) { Task { await openDatabase() } },
                                ]),
                            ])
                        }
                    }
                } else {
                    Text("O ns não informou esta branch.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 30)
                }
            }
            .padding(12)
        }
        .scrollIndicators(.never)
    }

    private func branchCard(_ status: NsStatus.Branch) -> some View {
        let activity = ns.activity[branch]
        let running = status.services.filter { $0.state == .rodando }.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text(branch)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if let activity {
                HStack(spacing: 7) {
                    ProgressView().controlSize(.mini)
                    Text(activity.label)
                }
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.accentSoft)
            } else if let problem = ns.actionProblems[branch] {
                Text(problem)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.removed)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !status.services.isEmpty {
                Text("\(running) de \(status.services.count) Rodando")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
            }
            HStack(spacing: 6) {
                action("Iniciar", help: BranchActionTitle.start, symbol: "play.fill") { await ns.start(branch) }
                action("Parar", help: BranchActionTitle.stop, symbol: "stop.fill") { await ns.stop(branch) }
                action("Atualizar", help: BranchActionTitle.update, symbol: "arrow.down.to.line") { await ns.update(branch) }
            }
            .disabled(activity != nil)
        }
        .padding(12)
        .modifier(CardBackground())
    }

    private func action(_ title: String, help: String, symbol: String,
                        perform: @escaping () async -> Void) -> some View {
        Button { Task { await perform() } } label: {
            Label(title, systemImage: symbol)
                .labelStyle(.titleAndIcon)
                .font(.system(size: 12.5))
                .frame(maxWidth: .infinity)
                .frame(height: 28)
        }
        .buttonStyle(.denSecondary)
        .help(help)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(Theme.textTertiary)
            .padding(.horizontal, 2)
    }

    private func card(@ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0, content: content)
            .modifier(CardBackground())
    }

    private func row(name: String, detail: String?, state: ServiceState,
                     isDatabase: Bool = false, isFirst: Bool,
                     @ViewBuilder actions: () -> some View = { EmptyView() }) -> some View {
        HStack(spacing: 10) {
            ServiceDot(state: state, isDatabase: isDatabase)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                if let detail {
                    Text(detail)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            Spacer(minLength: 8)
            Text(state.label)
                .font(.system(size: 11.5))
                .foregroundStyle(state == .parado ? Theme.textTertiary : ServiceDot.color(state))
                .frame(width: 62, alignment: .leading)
            actions()
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 9)
        .background {
            if state == .falhou {
                LinearGradient(colors: [Theme.removed.opacity(0.07), .clear], startPoint: .leading, endPoint: .trailing)
            }
        }
        .overlay(alignment: .top) {
            if !isFirst { Rectangle().fill(Theme.border).frame(height: 1) }
        }
        .accessibilityElement(children: .contain)
    }

    private func serviceActions(_ service: NsStatus.Service) -> some View {
        let isUp = service.state == .rodando || service.state == .iniciando
        return HStack(spacing: 1) {
            if isUp {
                iconAction("stop.fill", title: "Parar \(service.id)") { await ns.stop(branch, service: service.id) }
            } else {
                iconAction("play.fill", title: "Iniciar \(service.id)") { await ns.start(branch, service: service.id) }
            }
            iconAction("arrow.clockwise", title: "Reiniciar \(service.id)") {
                await ns.restart(branch, service: service.id)
            }
            .disabled(service.state == .parado)
            iconAction("terminal", title: "Abrir console de \(service.id)") { await openConsole(service) }
                .disabled(service.session == nil || service.state == .parado)
        }
        .disabled(ns.activity[branch] != nil)
    }

    private func iconAction(_ symbol: String, title: String, perform: @escaping () async -> Void) -> some View {
        Button { Task { await perform() } } label: {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .iconLabel(size: 26)
        }
        .buttonStyle(.denGhost(radius: 6))
        .help(title)
        .accessibilityLabel(title)
    }

    private func errorLine(_ service: NsStatus.Service) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 10.5))
            Text(service.error ?? "O processo terminou com erro")
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .help(service.error ?? "")
            if service.session != nil {
                Button("Ver no Console") { Task { await openConsole(service) } }
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .underline()
            }
        }
        .foregroundStyle(Theme.removed)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Theme.removedFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .padding(.leading, 29)
        .padding(.trailing, 8)
        .padding(.bottom, 8)
    }

    private func openDatabase() async {
        await ns.openDatabase(branch)
    }

    private func openConsole(_ service: NsStatus.Service) async {
        guard let session = service.session else { return }
        await terminals.openConsole(for: sessionID, branch: branch, service: service.id,
                                    session: session, in: directory)
    }
}

private struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        content
            .background(Theme.card, in: shape)
            .overlay(shape.strokeBorder(Theme.borderCard, lineWidth: 1))
    }
}
