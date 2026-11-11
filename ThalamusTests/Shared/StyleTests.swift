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
