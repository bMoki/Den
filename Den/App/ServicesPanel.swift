import SwiftUI

struct ServicesPanel: View {
    let branch: String

    @Environment(NsWorkspace.self) private var ns

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let status = ns.branch(named: branch) {
                    branchCard(status)
                    if !status.services.isEmpty {
                        sectionTitle("Serviços")
                        card {
                            ForEach(Array(status.services.enumerated()), id: \.element.id) { index, service in
                                row(name: service.id, detail: service.port.map { ":\($0)" },
                                    state: service.state, isFirst: index == 0)
                            }
                        }
                        sectionTitle("Banco")
                        card {
                            row(name: "postgres", detail: status.databasePort.map { ":\($0)" },
                                state: status.database, isDatabase: true, isFirst: true)
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
                     isDatabase: Bool = false, isFirst: Bool) -> some View {
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
        .accessibilityElement(children: .combine)
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
