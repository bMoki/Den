import SwiftUI
import AppKit

struct SettingsView: View {
    let defaults: UserDefaults

    var body: some View {
        TabView {
            GitHubSettings()
                .tabItem { Label("GitHub", icon: .pullRequest) }
            IndicatorSettings(defaults: defaults)
                .tabItem { Label("Indicadores", icon: .indicatorsTab) }
            SessionDefaultSettings(defaults: defaults)
                .tabItem { Label("Sessões", icon: .sessionsTab) }
        }
        .frame(width: 520)
    }
}

private struct GitHubSettings: View {
    @Environment(PullRequestMonitor.self) private var monitor
    @AppStorage(GitHubCLI.pathKey) private var path = ""

    var body: some View {
        Form {
            Section("GitHub CLI") {
                LabeledContent("Caminho") {
                    HStack {
                        TextField("Caminho", text: $path, prompt: Text("Detectar automaticamente"))
                            .labelsHidden()
                            .font(Theme.font(.small, design: .monospaced))
                            .onSubmit(apply)
                        Button("Escolher…", action: choose)
                    }
                }
                LabeledContent("Estado") {
                    HStack {
                        stateLabel
                        Spacer()
                        Button("Detectar de novo") {
                            path = ""
                            apply()
                        }
                    }
                }
                Text("Vazio, o Thalamus procura o gh no PATH do seu shell e em /opt/homebrew/bin e /usr/local/bin.")
                    .font(Theme.font(.caption))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .task { await monitor.checkGh() }
    }

    @ViewBuilder
    private var stateLabel: some View {
        switch monitor.cli {
        case .ready(_, let version):
            Label("gh \(version) · logado em github.com", icon: .done)
                .foregroundStyle(Theme.palette.checks.passed)
        case .missing:
            Label("Não encontrado", icon: .close).foregroundStyle(Theme.palette.checks.failed)
        case .notLoggedIn(let host):
            Label("Sem login em \(host)", icon: .warning).foregroundStyle(Theme.palette.checks.warning)
        case .unknown:
            Text("Verificando…").foregroundStyle(.secondary)
        }
    }

    private func apply() {
        Task { await monitor.reconfigure(path: path.isEmpty ? nil : path) }
    }

    private func choose() {
        Task {
            if let chosen = await GhPathPicker.pick(for: monitor) { path = chosen }
        }
    }
}
