import AppKit

extension NSTextView {
    private static let lineTolerance: CGFloat = 0.5

    var isOnFirstLine: Bool { caretLine.map { $0.minY < Self.lineTolerance } ?? true }

    var isOnLastLine: Bool {
        guard let caret = caretLine, let layoutManager, let textContainer else { return true }
        return caret.maxY >= layoutManager.usedRect(for: textContainer).maxY - Self.lineTolerance
    }

    private var caretLine: NSRect? {
        guard let layoutManager, let textContainer else { return nil }
        layoutManager.ensureLayout(for: textContainer)
        let text = string as NSString
        let location = selectedRange().location
        guard text.length > 0 else { return nil }
        if location >= text.length, text.hasSuffix("\n") {
            return layoutManager.extraLineFragmentRect
        }
        let glyph = layoutManager.glyphIndexForCharacter(at: min(location, text.length - 1))
        return layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
    }
}
