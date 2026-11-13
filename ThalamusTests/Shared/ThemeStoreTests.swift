import AppKit
import Foundation
import Testing
import SwiftUI
@testable import Thalamus

private let testPalette: Palette = {
    var palette = Palette.indigo
    palette.id = "teste"
    palette.accents.fill = Color(hex: 0x123456)
    return palette
}()

private let testStyle: Style = {
    var style = Style.padrao
    style.id = "teste"
    style.codeLineHeight = 2
    return style
}()

@Test func withoutAChoiceTheThemeIsPadraoWithIndigo() {
    let scratch = ScratchDefaults()
    defer { scratch.remove() }
    let store = ThemeStore()
    store.use(style: testStyle, palette: testPalette)
    store.restore(from: scratch.defaults)
    #expect(store.style.id == Style.padrao.id)
    #expect(store.palette.id == Palette.indigo.id)
}

@Test func theChoiceComesBackAfterARelaunch() {
    let scratch = ScratchDefaults()
    defer { scratch.remove() }
    let defaults = scratch.defaults
    let catalogs = (styles: [Style.padrao, testStyle], palettes: [Palette.indigo, testPalette])
    let store = ThemeStore(styles: catalogs.styles, palettes: catalogs.palettes)
    store.choose(testStyle, in: defaults)
    store.choose(testPalette, in: defaults)

    let relaunched = ThemeStore(styles: catalogs.styles, palettes: catalogs.palettes)
    relaunched.restore(from: defaults)
    #expect(relaunched.style.id == "teste")
    #expect(relaunched.palette.id == "teste")
}

@Test func anUnknownChoiceFallsBackToTheDefaults() {
    let scratch = ScratchDefaults()
    defer { scratch.remove() }
    let defaults = scratch.defaults
    defaults.set("brasa", forKey: ThemeStore.paletteKey)
    defaults.set("nenhum", forKey: ThemeStore.styleKey)
    let store = ThemeStore()
    store.restore(from: defaults)
    #expect(store.palette.id == "indigo")
    #expect(store.style.id == "padrao")
}

@MainActor
private final class Seen {
    var fill: Color?
    var lineHeight: CGFloat?
    var followed: [String] = []
}

private struct Probe: View {
    let seen: Seen

    var body: some View {
        seen.fill = Theme.accentFill
        seen.lineHeight = Theme.style.codeLineHeight
        return Rectangle().fill(Theme.accentFill)
    }
}

@MainActor
private func settle(_ host: NSView, until done: () -> Bool) async {
    for _ in 0..<300 where !done() {
        try? await Task.sleep(for: .milliseconds(10))
        host.layoutSubtreeIfNeeded()
    }
}

@MainActor
@Test func theScreenFollowsANewStyleAndPaletteWithoutReopening() async {
    let before = (style: Theme.style, palette: Theme.palette)
    defer { ThemeStore.shared.use(style: before.style, palette: before.palette) }
    let seen = Seen()
    let host = NSHostingView(rootView: Probe(seen: seen))
    host.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
    host.layoutSubtreeIfNeeded()
    Theme.follow(seen) { $0.followed.append(Theme.palette.id) }
    #expect(seen.fill == Palette.indigo.accents.fill)
    #expect(seen.followed == ["indigo"])

    ThemeStore.shared.use(style: testStyle, palette: testPalette)
    await settle(host) { seen.fill == testPalette.accents.fill && seen.followed.count == 2 }

    #expect(seen.fill == testPalette.accents.fill)
    #expect(seen.lineHeight == 2)
    #expect(seen.followed == ["indigo", "teste"])
}
