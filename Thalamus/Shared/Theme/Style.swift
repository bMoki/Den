import AppKit
import SwiftUI

nonisolated struct Style: Sendable {
    enum TextSize: CaseIterable, Sendable {
        case tiny, tinyPlus, mini, miniPlus, label, labelPlus, caption, captionPlus,
             small, smallPlus, body, bodyPlus, large, heading3, headline, heading2, title3, heading1,
             title2, title, largeTitle, display
    }

    enum Radius: CGFloat, CaseIterable, Sendable {
        case r1 = 1, r2 = 2, r3 = 3, r4 = 4, r5 = 5, r6 = 6, r7 = 7, r8 = 8, r9 = 9, r10 = 10,
             r11 = 11, r12 = 12, r14 = 14, r16 = 16
    }

    enum Line: CGFloat, CaseIterable, Sendable {
        case hairline = 0.5, thin = 1, medium = 1.5, spinner = 1.6, ring = 2.5, thick = 3, heavy = 4.5
    }

    enum Space: CGFloat, CaseIterable, Sendable {
        case s1 = 1, s1Half = 1.5, s2 = 2, s3 = 3, s4 = 4, s5 = 5, s6 = 6, s7 = 7, s8 = 8, s9 = 9,
             s10 = 10, s11 = 11, s12 = 12, s14 = 14, s16 = 16, s18 = 18, s20 = 20, s22 = 22,
             s24 = 24, s26 = 26, s28 = 28, s29 = 29, s30 = 30, s32 = 32, s36 = 36, s96 = 96, s120 = 120
    }

    enum Size: CGFloat, CaseIterable, Sendable {
        case s2 = 2, s3 = 3, s5 = 5, s6 = 6, s7 = 7, s8 = 8, s10 = 10, s12 = 12, s14 = 14,
             s15 = 15, s16 = 16, s17 = 17, s18 = 18, s19 = 19, s20 = 20, s22 = 22, s24 = 24,
             s26 = 26, s28 = 28, s30 = 30, s32 = 32, s34 = 34, s36 = 36, s38 = 38, s40 = 40,
             s42 = 42, s44 = 44, s48 = 48, s56 = 56, s60 = 60, s62 = 62, s68 = 68
    }

    enum Elevation: CaseIterable, Sendable {
        case knob, floatingButton, tip, composer, lightbox, inspector
    }

    struct Shadow: Sendable {
        var opacity: Double
        var radius: CGFloat
        var x: CGFloat = 0
        var y: CGFloat = 0
    }

    enum IconArt: Equatable, Sendable {
        case symbol(String)
        case asset(String)
    }

    enum SessionStateLook: Sendable {
        case animatedDot
    }

    var font: @Sendable (TextSize, Font.Weight?, Font.Design?) -> Font
    var inlineCodeFont: @Sendable (TextSize, Font.Weight?) -> Font
    var boxFont: @Sendable (CGFloat, Font.Weight?) -> Font
    var nsFont: @Sendable (TextSize) -> NSFont
    var nsCodeFont: @Sendable (TextSize) -> NSFont
    var codeLineHeight: CGFloat
    var radius: @Sendable (Radius) -> CGFloat
    var boxRadius: @Sendable (CGFloat) -> CGFloat
    var line: @Sendable (Line) -> CGFloat
    var space: @Sendable (Space) -> CGFloat
    var size: @Sendable (Size) -> CGFloat
    var shadow: @Sendable (Elevation) -> Shadow
    var icon: @Sendable (Icon) -> IconArt
    var sessionStates: SessionStateLook
}

nonisolated extension Style {
    static let current = padrao

    static let padrao = Style(
        font: { .system(size: padraoPoints($0), weight: $1, design: $2) },
        inlineCodeFont: { .system(size: padraoPoints($0) - 1, weight: $1, design: .monospaced) },
        boxFont: { .system(size: $0 * 0.6, weight: $1) },
        nsFont: { .systemFont(ofSize: padraoPoints($0)) },
        nsCodeFont: { .monospacedSystemFont(ofSize: padraoPoints($0), weight: .regular) },
        codeLineHeight: 1.45,
        radius: \.rawValue,
        boxRadius: { $0 * 0.27 },
        line: \.rawValue,
        space: \.rawValue,
        size: \.rawValue,
        shadow: { elevation in
            switch elevation {
            case .knob: Shadow(opacity: 0.5, radius: 4, y: 1)
            case .floatingButton: Shadow(opacity: 0.35, radius: 10, y: 3)
            case .tip: Shadow(opacity: 0.45, radius: 12, y: 4)
            case .composer: Shadow(opacity: 0.35, radius: 20, y: 4)
            case .lightbox: Shadow(opacity: 0.33, radius: 24)
            case .inspector: Shadow(opacity: 0.5, radius: 28, x: -8)
            }
        },
        icon: { $0.isAsset ? .asset($0.rawValue) : .symbol($0.rawValue) },
        sessionStates: .animatedDot)

    private static func padraoPoints(_ size: TextSize) -> CGFloat {
        switch size {
        case .tiny: 8
        case .tinyPlus: 8.5
        case .mini: 9
        case .miniPlus: 9.5
        case .label: 10
        case .labelPlus: 10.5
        case .caption: 11
        case .captionPlus: 11.5
        case .small: 12
        case .smallPlus: 12.5
        case .body: 13
        case .bodyPlus: 13.5
        case .large: 14
        case .heading3: 14.5
        case .headline: 15
        case .heading2: 16.5
        case .title3: 17
        case .heading1: 19
        case .title2: 20
        case .title: 22
        case .largeTitle: 24
        case .display: 26
        }
    }

    func image(_ icon: Icon) -> Image {
        switch self.icon(icon) {
        case .symbol(let name): Image(systemName: name)
        case .asset(let name): Image(name)
        }
    }

    func nsImage(_ icon: Icon) -> NSImage? {
        switch self.icon(icon) {
        case .symbol(let name): NSImage(systemSymbolName: name, accessibilityDescription: nil)
        case .asset(let name): NSImage(named: name)
        }
    }

    func image(symbolNamed name: String) -> Image {
        Icon(rawValue: name).map(image) ?? Image(systemName: name)
    }

    static func symbolExists(_ name: String) -> Bool {
        !name.isEmpty && NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
    }
}

extension View {
    func elevation(_ elevation: Style.Elevation) -> some View {
        let shadow = Theme.style.shadow(elevation)
        return self.shadow(color: Theme.shadow.opacity(shadow.opacity), radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}
