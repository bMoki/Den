import Foundation
import Testing
@testable import Den

private func scratchDefaults() throws -> UserDefaults {
    let suite = "ServiceIndicatorTests.\(UUID().uuidString)"
    return try #require(UserDefaults(suiteName: suite))
}

@Test func theRowsAreTheRecognisedServicesThenTheDatabase() {
    #expect(IndicatorTarget.all.map(\.id) == ["backend", "frontend", "manager", "report-server", "banco"])
}

@Test func withNothingStoredEachRowShowsTheTechnologyLogo() {
    let icons = IndicatorTarget.all.map { $0.icon(encoded: nil) }

    #expect(icons == [.logo(.quarkus), .logo(.vite), .logo(.tailwind), .logo(.bun), .symbol("cylinder")])
}

@Test func choosingTheStandardIconStoresNothing() {
    #expect(IndicatorTarget.service("backend").encoded(for: .logo(.quarkus)) == nil)
    #expect(IndicatorTarget.database.encoded(for: .symbol("cylinder")) == nil)
}

@Test func choosingAnotherIconStoresIt() {
    #expect(IndicatorTarget.service("backend").encoded(for: .logo(.java)) == "logo:java")
    #expect(IndicatorTarget.service("frontend").encoded(for: .symbol("globe")) == "globe")
}

@Test func aStoredIconIsReadBack() {
    let backend = IndicatorTarget.service("backend")

    #expect(backend.icon(encoded: "logo:java") == .logo(.java))
    #expect(backend.icon(encoded: "server.rack") == .symbol("server.rack"))
}

@Test func aStoredSymbolThatNoLongerExistsShowsAsADot() {
    #expect(IndicatorTarget.service("backend").icon(encoded: "no.such.symbol.anywhere") == nil)
    #expect(IndicatorTarget.service("backend").icon(encoded: "logo:cobol") == nil)
}

@Test func twoServicesCanShareAnIcon() {
    #expect(IndicatorTarget.service("frontend").icon(encoded: "logo:react") == .logo(.react))
    #expect(IndicatorTarget.service("manager").icon(encoded: "logo:react") == .logo(.react))
}

@Test func onlyRealSymbolNamesAreAccepted() {
    #expect(IndicatorIcon.symbolExists("cylinder"))
    #expect(!IndicatorIcon.symbolExists("no.such.symbol.anywhere"))
    #expect(!IndicatorIcon.symbolExists(""))
}

@Test func everySuggestionCanBeDrawn() {
    let suggestions = IndicatorTarget.all.flatMap(\.suggestions)

    #expect(suggestions.allSatisfy { $0.isAvailable })
    #expect(IndicatorTarget.service("report-server").suggestions.prefix(2) == [.logo(.bun), .logo(.typescript)])
}

@Test func theCatalogHasEverySuggestionAndEveryLogoOnce() {
    let catalog = IndicatorIcon.catalog

    #expect(Set(catalog).isSuperset(of: IndicatorTarget.all.flatMap(\.suggestions)))
    #expect(Set(catalog).isSuperset(of: TechLogo.allCases.map(IndicatorIcon.logo)))
    #expect(Set(catalog).count == catalog.count)
}

@Test func restoringStandardsForgetsTheStyleAndEveryIcon() throws {
    let defaults = try scratchDefaults()
    defaults.set(IndicatorStyle.icons.rawValue, forKey: IndicatorStyle.storageKey)
    for target in IndicatorTarget.all {
        defaults.set("globe", forKey: target.storageKey)
    }
    defaults.set("kept", forKey: "Den.sidebarWidth")

    IndicatorPreferences.restoreStandards(in: defaults)

    #expect(defaults.string(forKey: IndicatorStyle.storageKey) == nil)
    #expect(IndicatorTarget.all.allSatisfy { defaults.string(forKey: $0.storageKey) == nil })
    #expect(defaults.string(forKey: "Den.sidebarWidth") == "kept")
}
