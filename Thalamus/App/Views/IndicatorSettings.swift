import SwiftUI

struct IndicatorSettings: View {
    let defaults: UserDefaults

    @AppStorage(IndicatorStyle.storageKey) private var style: IndicatorStyle?

    var body: some View {
        Form {
            Section {
                Picker("Estilo", selection: styleSelection) {
                    ForEach(IndicatorStyle.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Text("A cor mostra o Estado. Em Pontos, os ícones escolhidos ficam guardados para quando voltar a Ícones.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Section("Serviços") {
                ForEach(IndicatorTarget.services) { IndicatorRow(target: $0) }
            }
            Section("Banco") {
                IndicatorRow(target: .database)
            }
            Section {
                HStack {
                    Spacer()
                    Button("Restaurar padrões") { IndicatorPreferences.restoreStandards(in: defaults) }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minHeight: 600)
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
        LabeledContent(title) {
            Button { choosing = true } label: {
                HStack(spacing: 6) {
                    if let icon = current {
                        IndicatorGlyph(icon: icon, color: .primary, size: 14)
                        Text(icon.title)
                    } else {
                        ServiceDot(state: .rodando, isDatabase: target == .database)
                        Text("Ponto")
                    }
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .popover(isPresented: $choosing, arrowEdge: .trailing) {
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
        VStack(alignment: .leading, spacing: 12) {
            group("Sugestões", icons: target.suggestions)
            group("Todos", icons: IndicatorIcon.catalog)
            VStack(alignment: .leading, spacing: 6) {
                caption("Símbolo do sistema")
                HStack(spacing: 8) {
                    TextField("Símbolo", text: $typed, prompt: Text("ex.: hammer"))
                        .labelsHidden()
                        .multilineTextAlignment(.leading)
                        .font(.system(size: 12, design: .monospaced))
                        .onSubmit(useTyped)
                    preview
                    Button("Usar", action: useTyped)
                        .disabled(!typedExists)
                }
                if !trimmed.isEmpty, !typedExists {
                    Text("Símbolo não encontrado")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private var trimmed: String { typed.trimmingCharacters(in: .whitespaces) }
    private var typedExists: Bool { IndicatorIcon.symbolExists(trimmed) }

    private var preview: some View {
        Group {
            if typedExists {
                IndicatorGlyph(icon: .symbol(trimmed), color: .primary, size: 16)
            } else {
                Image(systemName: "questionmark.square.dashed")
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: 20, height: 20)
        .accessibilityHidden(true)
    }

    private func useTyped() {
        guard typedExists else { return }
        choose(.symbol(trimmed))
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
    }

    private func group(_ title: String, icons: [IndicatorIcon]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            caption(title)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(30), spacing: 4), count: 8), alignment: .leading, spacing: 4) {
                ForEach(icons) { icon in
                    Button { choose(icon) } label: {
                        IndicatorGlyph(icon: icon, color: .primary, size: 15)
                            .frame(width: 30, height: 30)
                            .background(icon == current ? Color.accentColor.opacity(0.25) : .clear,
                                        in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(icon.title)
                    .accessibilityLabel(icon.title)
                }
            }
        }
    }
}
