import Foundation
import Testing
import SwiftUI
@testable import Thalamus

private func iconTable() throws -> Set<String> {
    let spec = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "docs/specs/estilo-tty-icones.md")
    let rows = try String(contentsOf: spec, encoding: .utf8).split(separator: "\n")
    return Set(rows.compactMap { row in
        row.hasPrefix("| `") ? row.split(separator: "`")[1].description : nil
    })
}

@Test func padraoIsTheCurrentStyle() {
    #expect(Theme.radius(.r12) == Style.padrao.radius(.r12))
    #expect(Theme.style.icon(.close) == Style.padrao.icon(.close))
}

@Test func everyIconHasARowInTheIconTable() throws {
    #expect(Set(Icon.allCases.map(\.rawValue)) == (try iconTable()))
}

@Test func padraoDrawsEveryIcon() {
    let missing = Icon.allCases.filter { Style.padrao.nsImage($0) == nil }
    #expect(missing.isEmpty)
}

@Test func padraoDrawsTheIconsTheScreensHadBefore() {
    #expect(Style.padrao.icon(.close) == .symbol("xmark"))
    #expect(Style.padrao.icon(.send) == .symbol("arrow.up"))
    #expect(Style.padrao.icon(.quarkusLogo) == .asset("logo-quarkus"))
    #expect(Style.padrao.icon(.claudeCode) == .asset("HarnessClaudeCode"))
}

@Test func padraoKeepsTheShapesTheScreensHadBefore() {
    let padrao = Style.padrao
    #expect(padrao.font(.smallPlus, .medium, .monospaced) == .system(size: 12.5, weight: .medium, design: .monospaced))
    #expect(padrao.font(.display, nil, nil) == .system(size: 26))
    #expect(padrao.inlineCodeFont(.large, .semibold) == .system(size: 13, weight: .semibold, design: .monospaced))
    #expect(padrao.nsFont(.body) == .systemFont(ofSize: 13))
    #expect(padrao.nsCodeFont(.small) == .monospacedSystemFont(ofSize: 12, weight: .regular))
    #expect(padrao.codeLineHeight == 1.45)
    #expect(padrao.radius(.r12) == 12)
    #expect(abs(padrao.boxRadius(20) - 5.4) < 0.001)
    #expect(padrao.line(.hairline) == 0.5)
    #expect(padrao.space(.s1Half) == 1.5)
    #expect(padrao.size(.s34) == 34)
    #expect(padrao.shadow(.inspector).x == -8)
}

@Test func padraoShowsTheSessionStatesAsTheAnimatedDot() {
    #expect(Style.padrao.sessionStates == .animatedDot)
}

@Test func ttyIsAStyleChoice() {
    #expect(Style.all.map(\.id) == ["padrao", "tty"])
}

@Test func ttyHasAGlyphForEveryIconInTheTable() throws {
    #expect(Set(Style.ttyGlyphs.keys).union([Icon.claudeCode.rawValue]) == (try iconTable()))
    #expect(Icon.allCases.allSatisfy { Style.tty.icon($0) != .glyph(Style.ttyMissingGlyph) })
}

@Test func ttyShowsTheClaudeLogoWithoutItsBackground() {
    #expect(Style.tty.icon(.claudeCode) == .asset(Style.ttyClaudeMark))
    #expect(Style.tty.nsImage(.claudeCode) != nil)
}

@Test func ttyEmbedsAFontThatHasEveryGlyphItDraws() {
    let font = Style.tty.nsFont(.body)
    #expect(font.fontName == "JetBrainsMonoNLNFM-Regular")
    let drawn = Array(Style.ttyGlyphs.values) + Array(GlyphSpinner.codes) + "─│┌┐└┘├┤░▒▓█▾▸▲■●×!›‹❯•⏎".unicodeScalars.map(\.value)
    let missing = drawn.filter { code in
        var units = Array(String(Character(Unicode.Scalar(code) ?? "?")).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: units.count)
        return !CTFontGetGlyphsForCharacters(font, &units, &glyphs, units.count)
    }
    #expect(missing.isEmpty)
}

@Test func ttyDrawsBoxesWithoutCornersOrShadowsInOneSize() {
    let tty = Style.tty
    #expect(Style.TextSize.allCases.allSatisfy { tty.nsFont($0).pointSize == Style.ttyPoints })
    #expect(Style.Radius.allCases.allSatisfy { tty.radius($0) == 0 })
    #expect(Style.Elevation.allCases.allSatisfy { tty.shadow($0).opacity == 0 })
    #expect(Style.Space.allCases.allSatisfy { tty.space($0).truncatingRemainder(dividingBy: 4) == 0 })
    #expect(tty.boxes == .lines && tty.marks == .characters && tty.sessionStates == .glyphWord)
}

@Test func ttyShowsAHandTypedSymbolAsTheMissingIndicator() {
    #expect(Style.tty.art(symbolNamed: "tortoise") == Style.tty.icon(.noIndicator))
    #expect(Style.tty.art(symbolNamed: "server.rack") == Style.tty.icon(.services))
    #expect(Style.padrao.art(symbolNamed: "tortoise") == .symbol("tortoise"))
}
