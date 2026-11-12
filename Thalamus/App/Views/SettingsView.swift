import SwiftUI
import AppKit

struct SettingsView: View {
    let defaults: UserDefaults

    @State private var tab = SettingsTab.gitHub

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.space(.s4)) {
                ForEach(SettingsTab.allCases) { tab in
                    SettingsTabButton(tab: tab, isSelected: self.tab == tab) { self.tab = tab }
                }
            }
            .padding(.vertical, Theme.space(.s8))
            .frame(maxWidth: .infinity)
            Rectangle().fill(Theme.border).frame(height: Theme.line(.thin))
            switch tab {
            case .gitHub:
                GitHubSettings()
            case .indicators:
                scrolling(IndicatorSettings(defaults: defaults))
            case .sessions:
                scrolling(SessionDefaultSettings(defaults: defaults))
            case .appearance:
                AppearanceSettings(defaults: defaults)
            }
        }
        .frame(width: 520)
        .foregroundStyle(Theme.text)
        .background(Theme.canvas)
        .navigationTitle(tab.title)
    }

    private static let scrollingHeight: CGFloat = 600

    private func scrolling(_ page: some View) -> some View {
        ScrollView { page }
            .frame(height: Self.scrollingHeight)
    }
}

enum SettingsTab: CaseIterable, Identifiable {
    case gitHub, indicators, sessions, appearance

    var id: Self { self }

    var title: String {
        switch self {
        case .gitHub: "GitHub"
        case .indicators: "Indicadores"
        case .sessions: "Sessões"
        case .appearance: "Aparência"
        }
    }

    var icon: Icon {
        switch self {
        case .gitHub: .pullRequest
        case .indicators: .indicatorsTab
        case .sessions: .sessionsTab
        case .appearance: .appearanceTab
        }
    }
}

private struct SettingsTabButton: View {
    let tab: SettingsTab
    let isSelected: Bool
    var select: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: select) {
            VStack(spacing: Theme.space(.s3)) {
                Theme.image(tab.icon)
                    .font(Theme.font(.title3))
                    .frame(height: Theme.size(.s22))
                Text(tab.title)
                    .font(Theme.font(.caption))
            }
            .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
            .padding(.horizontal, Theme.space(.s10))
            .frame(minWidth: Theme.size(.s68), minHeight: Theme.size(.s48))
            .hoverFill(hovering, selected: isSelected)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct GitHubSettings: View {
    @Environment(PullRequestMonitor.self) private var monitor
    @AppStorage(GitHubCLI.pathKey) private var path = ""

    var body: some View {
        SettingsPage {
            SettingsSection(title: "GitHub CLI") {
                SettingsRow(title: "Caminho") {
                    SettingsField(label: "Caminho", text: $path, prompt: "Detectar automaticamente", submit: apply)
                    SettingsButton(title: "Escolher…", action: choose)
                }
                SettingsRow(title: "Estado") {
                    stateLabel.font(Theme.font(.small))
                    SettingsButton(title: "Detectar de novo") {
                        path = ""
                        apply()
                    }
                }
                SettingsNote(text: "Vazio, o Thalamus procura o gh no PATH do seu shell e em /opt/homebrew/bin e /usr/local/bin.")
            }
        }
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
            Text("Verificando…").foregroundStyle(Theme.textTertiary)
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
