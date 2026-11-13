import SwiftUI
import HarnessCore

struct SessionDefaultSettings: View {
    let defaults: UserDefaults
    var registry: HarnessRegistry = .standard

    @State private var offered: [HarnessID: [HarnessKnob]] = [:]
    @State private var chosen: [HarnessID: [String: String]] = [:]

    private var cache: SessionCache { SessionCache(defaults: defaults) }

    var body: some View {
        SettingsPage {
            SettingsNote(text: "Vale para as Sessões novas. O que se escolhe dentro de uma Sessão fica só nela.")
            ForEach(registry.ids, id: \.self) { harness in
                SettingsSection(title: registry.displayName(for: harness)) { controls(of: harness) }
            }
        }
        .onAppear(perform: load)
    }

    @ViewBuilder
    private func controls(of harness: HarnessID) -> some View {
        let knobs = offered[harness] ?? []
        if knobs.isEmpty {
            SettingsNote(text: "Abra uma Sessão do \(registry.displayName(for: harness)) para ver as opções.")
        }
        ForEach(knobs) { knob in
            SessionDefaultRow(knob: knob, value: binding(knob.id, harness))
        }
        let vanished = (chosen[harness] ?? [:]).filter { id, _ in !knobs.contains { $0.id == id } }
        ForEach(vanished.sorted { $0.key < $1.key }, id: \.key) { id, value in
            SettingsRow(title: id) {
                SettingsButton(title: "Usar o padrão do harness") { binding(id, harness).wrappedValue = nil }
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
        SettingsRow(title: knob.name) {
            SettingsMenu(sections: sections) {
                Text(shownLabel)
            }
            .accessibilityLabel(knob.name)
            .accessibilityValue(shownLabel)
        }
        if let unavailable { Self.unavailableNote(unavailable) }
    }

    private var unavailableTitle: String? { unavailable.map { "\($0) (indisponível)" } }

    private var shownLabel: String {
        guard let value else { return Self.harnessDefault }
        if let unavailableTitle { return unavailableTitle }
        return knob.label(for: value) ?? value
    }

    private var sections: [ThalamusMenuSection] {
        var first = [item(Self.harnessDefault, nil)]
        if let unavailable, let unavailableTitle { first.append(item(unavailableTitle, unavailable)) }
        return [ThalamusMenuSection(id: "default", items: first)]
            + knob.groupedOptions.enumerated().map { index, group in
                ThalamusMenuSection(id: group.group ?? "options-\(index)", header: group.group,
                                    items: group.options.map { item($0.label, $0.value) })
            }
    }

    private func item(_ title: String, _ option: String?) -> ThalamusMenuItem {
        ThalamusMenuItem(id: option ?? "harness-default", title: title, isSelected: value == option) {
            value = option
        }
    }

    static func unavailableNote(_ value: String) -> some View {
        SettingsNote(text: "O harness não oferece mais \(value): as Sessões novas usam o padrão do harness.",
                     color: Theme.palette.checks.warning)
    }
}
