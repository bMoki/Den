import Foundation
import HarnessCore

nonisolated struct SessionCache {
    let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    static let standard = SessionCache(defaults: .standard)

    private func catalogKey(_ directory: URL, _ harness: HarnessID) -> String {
        PreferenceKey.named("catalog.") + harness.rawValue + "." + directory.standardizedFileURL.path
    }

    private func lastCatalogKey(_ harness: HarnessID) -> String {
        PreferenceKey.named("catalog.last.") + harness.rawValue
    }

    func remember(_ catalog: CommandCatalog, for directory: URL,
                  harness: HarnessID) {
        guard !catalog.isEmpty,
              let data = try? JSONEncoder().encode(catalog) else { return }
        defaults.set(data, forKey: catalogKey(directory, harness))
        defaults.set(data, forKey: lastCatalogKey(harness))
    }

    func rememberedCatalog(for directory: URL,
                           harness: HarnessID) -> CommandCatalog {
        for key in [catalogKey(directory, harness), lastCatalogKey(harness)] {
            if let data = defaults.data(forKey: key),
               let catalog = try? JSONDecoder().decode(CommandCatalog.self, from: data) {
                return catalog
            }
        }
        return .empty
    }

    private func knobsKey(_ harness: HarnessID) -> String {
        PreferenceKey.named("knobs.") + harness.rawValue
    }

    func remember(_ knobs: [HarnessKnob], for harness: HarnessID) {
        guard !knobs.isEmpty, let data = try? JSONEncoder().encode(knobs) else { return }
        defaults.set(data, forKey: knobsKey(harness))
    }

    func rememberedKnobs(for harness: HarnessID) -> [HarnessKnob] {
        guard let data = defaults.data(forKey: knobsKey(harness)),
              let knobs = try? JSONDecoder().decode([HarnessKnob].self, from: data)
        else { return [] }
        return knobs
    }

    private let harnessPreferencesKey = PreferenceKey.named("sessionHarnessPreferences")

    private let legacyPreferencesKey = PreferenceKey.named("sessionPreferences")

    func preferences(for sessionID: UUID, harness: HarnessID) -> [String: String]? {
        let all = defaults.dictionary(forKey: harnessPreferencesKey)
            as? [String: [String: [String: String]]] ?? [:]
        if let session = all[sessionID.uuidString] { return session[harness.rawValue] }
        let legacy = defaults.dictionary(forKey: legacyPreferencesKey)
            as? [String: [String: String]] ?? [:]
        return legacy[sessionID.uuidString]
    }

    func setPreferences(_ values: [String: String], for sessionID: UUID, harness: HarnessID) {
        var all = defaults.dictionary(forKey: harnessPreferencesKey)
            as? [String: [String: [String: String]]] ?? [:]
        all[sessionID.uuidString, default: [:]][harness.rawValue] = values
        defaults.set(all, forKey: harnessPreferencesKey)

        var legacy = defaults.dictionary(forKey: legacyPreferencesKey)
            as? [String: [String: String]] ?? [:]
        guard legacy.removeValue(forKey: sessionID.uuidString) != nil else { return }
        defaults.set(legacy, forKey: legacyPreferencesKey)
    }

    func forgetPreferences(of sessionID: UUID) {
        var all = defaults.dictionary(forKey: harnessPreferencesKey)
            as? [String: [String: [String: String]]] ?? [:]
        guard all.removeValue(forKey: sessionID.uuidString) != nil else { return }
        defaults.set(all, forKey: harnessPreferencesKey)
    }

    private let sessionDefaultsKey = PreferenceKey.named("sessionDefaults")

    func sessionDefault(for harness: HarnessID) -> [String: String] {
        let all = defaults.dictionary(forKey: sessionDefaultsKey)
            as? [String: [String: String]] ?? [:]
        return all[harness.rawValue] ?? [:]
    }

    func setSessionDefault(_ value: String?, knob: String, for harness: HarnessID) {
        var all = defaults.dictionary(forKey: sessionDefaultsKey)
            as? [String: [String: String]] ?? [:]
        all[harness.rawValue, default: [:]][knob] = value
        defaults.set(all, forKey: sessionDefaultsKey)
    }

    func offeredSessionDefault(for harness: HarnessID, among knobs: [HarnessKnob]) -> [String: String] {
        sessionDefault(for: harness).filter { id, value in knobs.contains { $0.id == id && $0.offers(value) } }
    }
}
