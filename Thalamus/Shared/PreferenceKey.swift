nonisolated enum PreferenceKey {
    static let prefix = "Thalamus."

    static func named(_ name: String) -> String {
        prefix + name
    }
}
