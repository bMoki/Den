import Testing
import SwiftUI
@testable import Thalamus

private func distinct(_ colors: [Color]) -> Bool {
    Set(colors.map { NSColor($0).usingColorSpace(.sRGB) }).count == colors.count
}

@Test func indigoIsTheCurrentPalette() {
    #expect(Theme.canvas == Palette.indigo.surfaces.canvas)
    #expect(Theme.accent == Palette.indigo.accents.accent)
}

@Test func indigoTellsTheSessionStatesApart() {
    let states = Palette.indigo.sessionStates
    #expect(distinct([states.awaitingDecision, states.outOfTokens, states.newReply, states.thinking]))
}

@Test func indigoTellsTheChangesApart() {
    let changes = Palette.indigo.changes
    #expect(distinct([changes.added, changes.removed, changes.modified]))
}

@Test func indigoHasTheSixteenTerminalColors() {
    #expect(Palette.indigo.terminalANSI.count == 16)
}

@Test func indigoKeepsTheColorsTheScreensHadBefore() {
    let indigo = Palette.indigo
    #expect(indigo.surfaces.canvas == Color(hex: 0x0F1115))
    #expect(indigo.surfaces.tip == Color(hex: 0x1E222B))
    #expect(indigo.accents.accent == Color(hex: 0x8B93FF))
    #expect(indigo.sessionStates.awaitingDecision == Color(hex: 0xEBC46A))
    #expect(indigo.contextCategories.tools == Color(hex: 0xE8906F))
    #expect(indigo.syntax.keyword == Color(hex: 0xB4A8FF))
    #expect(indigo.texts.inlineCode == Color(hex: 0xA8AEFF))
    #expect(indigo.terminalANSI.first == Color(hex: 0x000000))
    #expect(indigo.terminalANSI.last == Color(hex: 0xE9EBEB))
}
