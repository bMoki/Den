import SwiftUI

struct ServicesPanel: View {
    let branch: String
    let directory: URL

    @Environment(NsWorkspace.self) private var ns
    @Environment(PanelTerminals.self) private var terminals
    @Environment(PullRequestMonitor.self) private var monitor

    @State private var takingSnapshot = false
    @State private var restoring: RestoreRequest?
    @State private var removing: NsClient.Snapshot?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.space(.s12)) {
                if let status = ns.branch(named: branch) {
                    branchCard(status)
                    if !status.services.isEmpty {
                        sectionTitle("Serviços")
                        card {
                            ForEach(Array(status.services.enumerated()), id: \.element.id) { index, service in
                                VStack(spacing: 0) {
                                    row(name: service.id, detail: service.port.map { ":\($0)" },
                                        state: service.state, indicator: .service(service.id), isFirst: index == 0) {
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
                                state: status.database, indicator: .database, isFirst: true) {
                                iconAction(.openInApp, title: BranchActionTitle.openDatabase, perform: openDatabase)
                                    .disabled(ns.activity[branch] != nil)
                                ThalamusMenuChip(sections: databaseMenu, radius: .r6, arrowEdge: .leading,
                                                 opened: { Task { await ns.loadSnapshots() } }, label: {
                                    Theme.image(.databaseSection)
                                        .font(Theme.font(.caption, weight: .medium))
                                        .foregroundStyle(Theme.textSecondary)
                                        .iconLabel(size: .s26)
                                })
                                .tip("Snapshots")
                                .accessibilityLabel("Snapshots")
                            }
                            .thalamusContextMenu(databaseMenu)
                        }
                    }
                    if ns.dependencies.isShown(for: branch) {
                        sectionTitle("Dependências")
                        DependenciesSection(branch: branch, isBusy: ns.activity[branch] != nil)
                    }
                    let repos = monitor.repos(of: branch)
                    if !repos.isEmpty {
                        sectionTitle("Pull requests")
                        card { BranchPullRequestRows(repos: repos) }
                    }
                } else {
                    Text("O ns não informou esta branch.")
                        .font(Theme.font(.smallPlus))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.space(.s30))
                }
            }
            .padding(Theme.space(.s12))
        }
        .scrollIndicators(.never)
        .task(id: branch) {
            async let snapshots: Void = ns.loadSnapshots()
            await ns.dependencies.load(branch)
            await snapshots
        }
        .sheet(isPresented: $takingSnapshot) {
            TakeSnapshotSheet(branch: branch, taken: Set(ns.snapshots(of: branch).map(\.name)),
                              cancel: { takingSnapshot = false }, take: { name, replacing in
                                  takingSnapshot = false
                                  Task { await ns.takeSnapshot(branch, name: name, replacing: replacing) }
                              })
        }
        .sheet(item: $restoring) { request in
            RestoreSnapshotSheet(branch: branch, sources: ns.restoreSources(for: branch), running: runningServices,
                                 problem: ns.snapshotsProblem, selected: request.selected,
                                 cancel: { restoring = nil }, restore: { ref in
                                     restoring = nil
                                     Task { await ns.restore(branch, from: ref) }
                                 })
        }
        .confirmation("Remover \(removing?.ref ?? "")?", isPresented: Binding(
            get: { removing != nil },
            set: { if !$0 { removing = nil } }
        ), message: "Apaga o Snapshot e o volume dele. Não dá para desfazer.", choices: [
            ConfirmationChoice(title: "Remover", isDestructive: true) {
                if let snapshot = removing { Task { await ns.removeSnapshot(snapshot) } }
            },
        ])
    }

    private var runningServices: [String] {
        ns.branch(named: branch)?.services.filter { $0.state == .rodando }.map(\.id) ?? []
    }

    private var databaseMenu: [ThalamusMenuSection] {
        let idle = ns.activity[branch] == nil
        let snapshots = ns.snapshots(of: branch)
        var listed = snapshots.map { snapshot in
            ThalamusMenuItem(id: snapshot.ref, title: snapshotTitle(snapshot), isEnabled: idle, children: [
                ThalamusMenuSection(items: [
                    ThalamusMenuItem(id: "restore", title: "Restaurar…") { restoring = RestoreRequest(selected: snapshot.ref) },
                    ThalamusMenuItem(id: "remove", title: "Remover…", isDestructive: true) { removing = snapshot },
                ]),
            ])
        }
        if snapshots.isEmpty {
            listed = [ThalamusMenuItem(id: "none", title: ns.snapshotsProblem ?? "Nenhum snapshot", isEnabled: false)]
        }
        return [
            ThalamusMenuSection(id: "open", items: [
                ThalamusMenuItem(id: "open", title: BranchActionTitle.openDatabase, isEnabled: idle) { Task { await openDatabase() } },
            ]),
            ThalamusMenuSection(id: "snapshot", items: [
                ThalamusMenuItem(id: "take", title: "Tirar snapshot…", isEnabled: idle) { takingSnapshot = true },
                ThalamusMenuItem(id: "restore", title: "Restaurar…", isEnabled: idle) { restoring = RestoreRequest() },
            ]),
            ThalamusMenuSection(id: "snapshots", header: "Snapshots desta branch", items: listed),
        ]
    }

    private func snapshotTitle(_ snapshot: NsClient.Snapshot) -> String {
        snapshot.age.map { "\(snapshot.name) · \($0)" } ?? snapshot.name
    }

    private func branchCard(_ status: NsStatus.Branch) -> some View {
        let activity = ns.activity[branch]
        let running = status.services.filter { $0.state == .rodando }.count
        return VStack(alignment: .leading, spacing: Theme.space(.s10)) {
            HStack(spacing: Theme.space(.s8)) {
                Theme.image(.branch)
                    .font(Theme.font(.small, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                Text(branch)
                    .font(Theme.font(.body, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if let activity {
                HStack(spacing: Theme.space(.s7)) {
                    ProgressView().controlSize(.mini)
                    Text(activity.label)
                }
                .font(Theme.font(.captionPlus))
                .foregroundStyle(Theme.accentSoft)
            } else if let problem = ns.actionProblems[branch] {
                Text(problem)
                    .font(Theme.font(.captionPlus))
                    .foregroundStyle(Theme.removed)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !status.services.isEmpty {
                Text("\(running) de \(status.services.count) Rodando")
                    .font(Theme.font(.captionPlus))
                    .foregroundStyle(Theme.textTertiary)
            }
            HStack(spacing: Theme.space(.s6)) {
                action("Iniciar", help: BranchActionTitle.start, symbol: .start) { await ns.start(branch) }
                action("Parar", help: BranchActionTitle.stop, symbol: .stop) { await ns.stop(branch) }
                action("Atualizar", help: BranchActionTitle.update, symbol: .updateBranch) { await ns.update(branch) }
            }
            .disabled(activity != nil || ns.dependencies.isInstalling(in: branch))
        }
        .padding(Theme.space(.s12))
        .modifier(CardBackground())
    }

    private func action(_ title: String, help: String, symbol: Icon,
                        perform: @escaping () async -> Void) -> some View {
        Button { Task { await perform() } } label: {
            Label(title, icon: symbol)
                .labelStyle(.titleAndIcon)
                .font(Theme.font(.smallPlus))
                .frame(maxWidth: .infinity)
                .frame(height: Theme.size(.s28))
        }
        .buttonStyle(.thalamusSecondary)
        .tip(help)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(Theme.font(.captionPlus, weight: .semibold))
            .foregroundStyle(Theme.textTertiary)
            .padding(.horizontal, Theme.space(.s2))
    }

    private func card(@ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0, content: content)
            .modifier(CardBackground())
    }

    private func row(name: String, detail: String?, state: ServiceState,
                     indicator: IndicatorTarget, isFirst: Bool,
                     @ViewBuilder actions: () -> some View = { EmptyView() }) -> some View {
        HStack(spacing: Theme.space(.s10)) {
            ServiceIndicator(indicator, state: state, iconSize: .s14)
            VStack(alignment: .leading, spacing: Theme.space(.s1)) {
                Text(name)
                    .font(Theme.font(.body, weight: .medium))
                if let detail {
                    Text(detail)
                        .font(Theme.font(.caption, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            Spacer(minLength: Theme.space(.s8))
            Text(state.label)
                .font(Theme.font(.captionPlus))
                .foregroundStyle(ServiceDot.color(state))
                .frame(width: Theme.size(.s62), alignment: .leading)
            actions()
        }
        .padding(.leading, Theme.space(.s12))
        .padding(.trailing, Theme.space(.s8))
        .padding(.vertical, Theme.space(.s9))
        .background {
            if state == .falhou {
                LinearGradient(colors: [Theme.removed.opacity(0.07), .clear], startPoint: .leading, endPoint: .trailing)
            }
        }
        .overlay(alignment: .top) {
            if !isFirst { Rectangle().fill(Theme.border).frame(height: Theme.line(.thin)) }
        }
        .accessibilityElement(children: .contain)
    }

    private func serviceActions(_ service: NsStatus.Service) -> some View {
        let isUp = service.state == .rodando || service.state == .iniciando
        return HStack(spacing: Theme.space(.s1)) {
            if isUp {
                iconAction(.stop, title: "Parar \(service.id)") { await ns.stop(branch, service: service.id) }
            } else {
                iconAction(.start, title: "Iniciar \(service.id)") { await ns.start(branch, service: service.id) }
            }
            iconAction(.restart, title: "Reiniciar \(service.id)") {
                await ns.restart(branch, service: service.id)
            }
            .disabled(service.state == .parado)
            iconAction(.terminal, title: "Abrir console de \(service.id)") { await openConsole(service) }
                .disabled(service.session == nil || service.state == .parado)
        }
        .disabled(ns.activity[branch] != nil || ns.dependencies.isInstalling(in: branch))
    }

    private func iconAction(_ symbol: Icon, title: String, perform: @escaping () async -> Void) -> some View {
        Button { Task { await perform() } } label: {
            Theme.image(symbol)
                .font(Theme.font(.caption, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .iconLabel(size: .s26)
        }
        .buttonStyle(.thalamusGhost(radius: .r6))
        .tip(title)
        .accessibilityLabel(title)
    }

    private func errorLine(_ service: NsStatus.Service) -> some View {
        HStack(spacing: Theme.space(.s8)) {
            Theme.image(.warning)
                .font(Theme.font(.labelPlus))
            Text(service.error ?? "O processo terminou com erro")
                .font(Theme.font(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .tip(service.error ?? "")
            if service.session != nil {
                Button("Ver no Console") { Task { await openConsole(service) } }
                    .buttonStyle(.plain)
                    .font(Theme.font(.captionPlus, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .underline()
            }
        }
        .foregroundStyle(Theme.removed)
        .padding(.horizontal, Theme.space(.s8))
        .padding(.vertical, Theme.space(.s6))
        .background(Theme.removedFill, in: RoundedRectangle(cornerRadius: Theme.radius(.r7), style: .continuous))
        .padding(.leading, Theme.space(.s29))
        .padding(.trailing, Theme.space(.s8))
        .padding(.bottom, Theme.space(.s8))
    }

    private func openDatabase() async {
        await ns.openDatabase(branch)
    }

    private func openConsole(_ service: NsStatus.Service) async {
        guard let session = service.session else { return }
        await terminals.openConsole(branch: branch, service: service.id, session: session,
                                    in: ns.root(of: .branch(branch)) ?? directory)
    }
}

private struct RestoreRequest: Identifiable {
    let id = UUID()
    var selected: String?
}

private struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radius(.r12), style: .continuous)
        content
            .background(Theme.card, in: shape)
            .overlay(shape.strokeBorder(Theme.borderCard, lineWidth: Theme.line(.thin)))
    }
}
