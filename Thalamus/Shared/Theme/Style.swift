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
        case knob, floatingButton, tip, floating, composer, lightbox, inspector
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
        case glyph(UInt32)
    }

    enum SessionStateLook: Sendable {
        case animatedDot
        case glyphWord
    }

    enum Boxes: Sendable {
        case surfaces
        case lines
    }

    enum Marks: Sendable {
        case graphic
        case characters
    }

    enum AppIconDrawing: Sendable {
        case shapes
        case characters
    }

    var id: String
    var name: String
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
    var boxes: Boxes
    var marks: Marks
    var appIcon: AppIconDrawing
}

nonisolated extension Style: Identifiable {
    static let all = [padrao, tty]

    static let padrao = Style(
        id: "padrao", name: "Padrão",
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
            case .floating: Shadow(opacity: 0.4, radius: 14, y: 5)
            case .composer: Shadow(opacity: 0.35, radius: 20, y: 4)
            case .lightbox: Shadow(opacity: 0.33, radius: 24)
            case .inspector: Shadow(opacity: 0.5, radius: 28, x: -8)
            }
        },
        icon: { $0.isAsset ? .asset($0.rawValue) : .symbol($0.rawValue) },
        sessionStates: .animatedDot,
        boxes: .surfaces,
        marks: .graphic,
        appIcon: .shapes)

    static let tty = Style(
        id: "tty", name: "TTY",
        font: { _, weight, _ in .custom(ttyFace(weight), fixedSize: ttyPoints) },
        inlineCodeFont: { _, weight in .custom(ttyFace(weight), fixedSize: ttyPoints) },
        boxFont: { _, weight in .custom(ttyFace(weight), fixedSize: ttyPoints) },
        nsFont: { _ in ttyNSFont },
        nsCodeFont: { _ in ttyNSFont },
        codeLineHeight: 1.3,
        radius: { _ in 0 },
        boxRadius: { _ in 0 },
        line: { $0 == .hairline ? Line.thin.rawValue : $0.rawValue },
        space: { ($0.rawValue / ttyGrid).rounded() * ttyGrid },
        size: { max(ttyGrid / 2, ($0.rawValue / (ttyGrid / 2)).rounded() * (ttyGrid / 2)) },
        shadow: { _ in Shadow(opacity: 0, radius: 0) },
        icon: { $0 == .claudeCode ? .asset(ttyClaudeMark) : .glyph(ttyGlyphs[$0.rawValue] ?? ttyMissingGlyph) },
        sessionStates: .glyphWord,
        boxes: .lines,
        marks: .characters,
        appIcon: .characters)

    static let ttyPoints: CGFloat = 13
    private static let ttyGrid: CGFloat = 4
    static let ttyMissingGlyph: UInt32 = 0x3F
    static let ttyClaudeMark = "HarnessClaudeCodeMark"
    private static let ttyRegular = "JetBrainsMonoNLNFM-Regular"
    private static let ttyBold = "JetBrainsMonoNLNFM-Bold"

    private static let ttyFontsRegistered: Bool = {
        let urls = ["Regular", "Bold", "Italic"].compactMap {
            Bundle.main.url(forResource: "JetBrainsMonoNLNerdFontMono-" + $0, withExtension: "ttf")
        }
        let registered = urls.map { CTFontManagerRegisterFontsForURL($0 as CFURL, .process, nil) }
        return registered.count == 3 && !registered.contains(false) || NSFont(name: ttyRegular, size: ttyPoints) != nil
    }()

    private static func ttyFace(_ weight: Font.Weight?) -> String {
        _ = ttyFontsRegistered
        return [Font.Weight.semibold, .bold, .heavy, Font.Weight.black].contains(weight) ? ttyBold : ttyRegular
    }

    static func ttyBoldFont(ofSize size: CGFloat) -> NSFont {
        NSFont(name: ttyFace(.bold), size: size) ?? .monospacedSystemFont(ofSize: size, weight: .bold)
    }

    static func bandFont(ofSize size: CGFloat) -> NSFont {
        .systemFont(ofSize: size, weight: .heavy)
    }

    private static let ttyNSFont: NSFont = NSFont(name: ttyFace(nil), size: ttyPoints)
        ?? .monospacedSystemFont(ofSize: ttyPoints, weight: .regular)

    static func character(_ code: UInt32) -> String {
        Unicode.Scalar(code).map { String(Character($0)) } ?? "?"
    }

    static func checkbox(_ isOn: Bool) -> String { isOn ? "[x]" : "[ ]" }

    private static let glyphImages = NSCache<NSString, NSImage>()

    static func padraoSymbol(_ icon: Icon, size: TextSize) -> NSImage? {
        guard case .symbol(let name) = padrao.icon(icon) else { return padraoSymbol(named: "square", size: size) }
        return padraoSymbol(named: name, size: size)
    }

    private static func padraoSymbol(named name: String, size: TextSize) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: padraoPoints(size), weight: .regular))
    }

    static func glyphImage(_ code: UInt32, like icon: Icon, size: TextSize) -> NSImage {
        let key = "\(code) \(icon.rawValue) \(size)" as NSString
        if let cached = glyphImages.object(forKey: key) { return cached }
        let reference = padraoSymbol(icon, size: size)
        let frame = reference?.size ?? CGSize(width: padraoPoints(size), height: padraoPoints(size))
        let target = reference.map(inkExtent) ?? padraoPoints(size)
        let text = character(code)
        let unit = NSFont(descriptor: ttyNSFont.fontDescriptor, size: 1) ?? ttyNSFont
        var units = Array(text.utf16)
        var glyphs = [CGGlyph](repeating: 0, count: units.count)
        CTFontGetGlyphsForCharacters(unit, &units, &glyphs, units.count)
        let unitInk = unit.boundingRect(forCGGlyph: glyphs[0])
        let points = min(target / max(unitInk.width, unitInk.height, 0.01),
                         frame.width / max(unitInk.width, 0.01), frame.height / max(unitInk.height, 0.01))
        let font = NSFont(descriptor: ttyNSFont.fontDescriptor, size: points) ?? ttyNSFont
        let ink = font.boundingRect(forCGGlyph: glyphs[0])
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
        let image = NSImage(size: frame, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.textPosition = CGPoint(x: rect.midX - ink.midX, y: rect.midY - ink.midY)
            CTLineDraw(line, context)
            return true
        }
        image.isTemplate = true
        glyphImages.setObject(image, forKey: key)
        return image
    }

    static func inkExtent(_ image: NSImage) -> CGFloat {
        let scale = 4
        let width = Int(ceil(image.size.width)) * scale
        let height = Int(ceil(image.size.height)) * scale
        guard width > 0, height > 0, let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: width * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return 0 }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let pixels = context.data?.assumingMemoryBound(to: UInt8.self) else { return 0 }
        var columns = Set<Int>()
        var rows = Set<Int>()
        for row in 0..<height {
            for column in 0..<width where pixels[(row * width + column) * 4 + 3] > 96 {
                columns.insert(column)
                rows.insert(row)
            }
        }
        let extent = max((columns.max() ?? -1) - (columns.min() ?? 0) + 1, (rows.max() ?? -1) - (rows.min() ?? 0) + 1)
        return CGFloat(extent) / CGFloat(scale)
    }

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
        image(icon, size: .body)
    }

    func image(_ icon: Icon, size: TextSize) -> Image {
        guard case .glyph(let code) = self.icon(icon) else { return image(of: self.icon(icon)) }
        return Image(nsImage: Self.glyphImage(code, like: icon, size: size))
    }

    private func image(of art: IconArt) -> Image {
        switch art {
        case .symbol(let name): Image(systemName: name)
        case .asset(let name): Image(name)
        case .glyph(let code): Image(nsImage: Self.glyphImage(code, like: .noIndicator, size: .body))
        }
    }

    func nsImage(_ icon: Icon) -> NSImage? {
        switch self.icon(icon) {
        case .symbol(let name): NSImage(systemSymbolName: name, accessibilityDescription: nil)
        case .asset(let name): NSImage(named: name)
        case .glyph(let code): Self.glyphImage(code, like: icon, size: .body)
        }
    }

    func image(symbolNamed name: String) -> Image {
        if let icon = Icon(rawValue: name) { return image(icon) }
        return marks == .characters ? image(.noIndicator) : image(of: .symbol(name))
    }

    func art(symbolNamed name: String) -> IconArt {
        if let icon = Icon(rawValue: name) { return self.icon(icon) }
        return marks == .characters ? icon(.noIndicator) : .symbol(name)
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
