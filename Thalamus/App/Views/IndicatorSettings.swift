import SwiftUI

struct IndicatorSettings: View {
    let defaults: UserDefaults

    @AppStorage(IndicatorStyle.storageKey) private var style: IndicatorStyle?

    var body: some View {
        SettingsPage {
            SettingsSection {
                SettingsRow(title: "Estilo") {
                    SettingsChoice(options: IndicatorStyle.allCases, selection: styleSelection, title: \.title)
                }
                SettingsNote(text: "A cor mostra o Estado. Em Pontos, os ícones escolhidos ficam guardados para quando voltar a Ícones.")
            }
            SettingsSection(title: "Serviços") {
                ForEach(IndicatorTarget.services) { IndicatorRow(target: $0) }
            }
            SettingsSection(title: "Banco") {
                IndicatorRow(target: .database)
            }
            HStack {
                Spacer()
                SettingsButton(title: "Restaurar padrões") { IndicatorPreferences.restoreStandards(in: defaults) }
            }
        }
    }

    private var styleSelection: Binding<IndicatorStyle> {
        Binding(get: { style ?? .standard },
                set: { style = $0 == .standard ? nil : $0 })
    }
}

private struct IndicatorRow: View {
    let target: IndicatorTarget

    @AppStorage private var encodedIcon: String?
    @State private var choosing = false

    init(target: IndicatorTarget) {
        self.target = target
        _encodedIcon = AppStorage(target.storageKey)
    }

    private var title: String { target.id }

    var body: some View {
        SettingsRow(title: title) {
            Button { choosing = true } label: {
                HStack(spacing: Theme.space(.s6)) {
                    if let icon = current {
                        IndicatorGlyph(icon: icon, color: Theme.text, size: .s14)
                        Text(icon.title)
                    } else {
                        ServiceDot(state: .rodando, isDatabase: target == .database)
                        Text("Ponto")
                    }
                    Chevron()
                }
                .settingsControl()
            }
            .buttonStyle(.settingsControl)
            .floating(isPresented: $choosing, edge: .trailing) {
                IndicatorChooser(target: target, current: current) { icon in
                    encodedIcon = target.encoded(for: icon)
                    choosing = false
                }
            }
            .accessibilityLabel("Ícone de \(title): \(current?.title ?? "Ponto")")
        }
    }

    private var current: IndicatorIcon? { target.icon(encoded: encodedIcon) }
}

private struct IndicatorChooser: View {
    let target: IndicatorTarget
    let current: IndicatorIcon?
    var choose: (IndicatorIcon) -> Void

    @State private var typed = ""

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space(.s12)) {
            group("Sugestões", icons: target.suggestions)
            group("Todos", icons: IndicatorIcon.catalog)
            VStack(alignment: .leading, spacing: Theme.space(.s6)) {
                caption("Símbolo do sistema")
                HStack(spacing: Theme.space(.s8)) {
                    SettingsField(label: "Símbolo", text: $typed, prompt: "ex.: hammer", submit: useTyped)
                    preview
                    SettingsButton(title: "Usar", action: useTyped)
                        .disabled(!typedExists)
                }
                if !trimmed.isEmpty, !typedExists {
                    Text("Símbolo não encontrado")
                        .font(Theme.font(.caption))
                        .foregroundStyle(Theme.palette.checks.failed)
                }
            }
        }
        .padding(Theme.space(.s14))
        .frame(width: 300)
    }

    private var trimmed: String { typed.trimmingCharacters(in: .whitespaces) }
    private var typedExists: Bool { Style.symbolExists(trimmed) }

    private var preview: some View {
        Group {
            if typedExists {
                IndicatorGlyph(icon: .symbol(trimmed), color: Theme.text, size: .s16)
            } else {
                Theme.image(.noIndicator)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .frame(width: Theme.size(.s20), height: Theme.size(.s20))
        .accessibilityHidden(true)
    }

    private func useTyped() {
        guard typedExists else { return }
        choose(.symbol(trimmed))
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(Theme.font(.caption, weight: .semibold))
            .foregroundStyle(Theme.textSecondary)
    }

    private func group(_ title: String, icons: [IndicatorIcon]) -> some View {
        VStack(alignment: .leading, spacing: Theme.space(.s6)) {
            caption(title)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: Theme.space(.s4)), count: 8), alignment: .leading, spacing: Theme.space(.s4)) {
                ForEach(icons) { icon in
                    Button { choose(icon) } label: {
                        IndicatorGlyph(icon: icon, color: Theme.text, size: .s15)
                            .frame(width: Theme.size(.s30), height: Theme.size(.s30))
                            .background(icon == current ? Theme.accent.opacity(0.25) : .clear,
                                        in: RoundedRectangle(cornerRadius: Theme.radius(.r6), style: .continuous))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .tip(icon.title)
                    .accessibilityLabel(icon.title)
                }
            }
        }
    }
}
