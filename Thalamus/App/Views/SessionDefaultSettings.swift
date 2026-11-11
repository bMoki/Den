import SwiftUI
import HarnessCore

struct SessionDefaultSettings: View {
    let defaults: UserDefaults
    var registry: HarnessRegistry = .standard

    @State private var offered: [HarnessID: [HarnessKnob]] = [:]
    @State private var chosen: [HarnessID: [String: String]] = [:]

    private var cache: SessionCache { SessionCache(defaults: defaults) }

    var body: some View {
        Form {
            Section {
                Text("Vale para as Sessões novas. O que se escolhe dentro de uma Sessão fica só nela.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            ForEach(registry.ids, id: \.self) { harness in
                Section(registry.displayName(for: harness)) { controls(of: harness) }
            }
        }
        .formStyle(.grouped)
        .frame(minHeight: 600)
        .onAppear(perform: load)
    }

    @ViewBuilder
    private func controls(of harness: HarnessID) -> some View {
        let knobs = offered[harness] ?? []
        if knobs.isEmpty {
            Text("Abra uma Sessão do \(registry.displayName(for: harness)) para ver as opções.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        ForEach(knobs) { knob in
            SessionDefaultRow(knob: knob, value: binding(knob.id, harness))
        }
        let vanished = (chosen[harness] ?? [:]).filter { id, _ in !knobs.contains { $0.id == id } }
        ForEach(vanished.sorted { $0.key < $1.key }, id: \.key) { id, value in
            LabeledContent(id) {
                Button("Usar o padrão do harness") { binding(id, harness).wrappedValue = nil }
            }
            SessionDefaultRow.unavailableNote(value)
        }
    }

    private func load() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        for harness in registry.ids {
            offered[harness] = registry.offeredKnobs(for: harness, in: home, cache: cache)
            chosen[harness] = cache.sessionDefault(for: harness)
        }
    }

    private func binding(_ knob: String, _ harness: HarnessID) -> Binding<String?> {
        Binding {
            chosen[harness]?[knob]
        } set: { value in
            cache.setSessionDefault(value, knob: knob, for: harness)
            chosen[harness, default: [:]][knob] = value
        }
    }
}

private struct SessionDefaultRow: View {
    static let harnessDefault = "Padrão do harness"

    let knob: HarnessKnob
    @Binding var value: String?

    private var unavailable: String? {
        value.flatMap { knob.offers($0) ? nil : $0 }
    }

    var body: some View {
        Picker(knob.name, selection: $value) {
            Text(Self.harnessDefault).tag(String?.none)
            if let unavailable {
                Text("\(unavailable) (indisponível)").tag(String?.some(unavailable))
            }
            ForEach(knob.groupedOptions, id: \.group) { group in
                if let title = group.group {
                    Section(title) { options(group.options) }
                } else {
                    options(group.options)
                }
            }
        }
        if let unavailable { Self.unavailableNote(unavailable) }
    }

    private func options(_ options: [HarnessKnob.Option]) -> some View {
        ForEach(options, id: \.value) { Text($0.label).tag(String?.some($0.value)) }
    }

    static func unavailableNote(_ value: String) -> some View {
        Text("O harness não oferece mais \(value): as Sessões novas usam o padrão do harness.")
            .font(.system(size: 11))
            .foregroundStyle(Theme.palette.checks.warning)
    }
}
