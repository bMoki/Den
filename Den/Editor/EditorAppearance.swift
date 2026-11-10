import AppKit
import CodeEditSourceEditor
import SwiftUI

extension SourceEditorConfiguration {
    static let thalamus = SourceEditorConfiguration(
        appearance: .init(theme: .thalamus, font: .monospacedSystemFont(ofSize: 12.5, weight: .regular), lineHeightMultiple: 1.45, wrapLines: false),
        peripherals: .init(showMinimap: false, showFoldingRibbon: false))

    static let thalamusReadOnly = {
        var configuration = thalamus
        configuration.behavior.isEditable = false
        return configuration
    }()
}

extension EditorTheme {
    static let thalamus = EditorTheme(
        text: attribute(Theme.text),
        insertionPoint: NSColor(Theme.accent),
        invisibles: attribute(Theme.textFaint),
        background: NSColor(Theme.canvas),
        lineHighlight: NSColor(Theme.accent.opacity(0.06)),
        selection: NSColor(Theme.accent.opacity(0.28)),
        keywords: attribute(SyntaxHighlighter.keywordColor),
        commands: attribute(Theme.accentSoft),
        types: attribute(SyntaxHighlighter.typeColor),
        attributes: attribute(SyntaxHighlighter.attributeColor),
        variables: attribute(Theme.text),
        values: attribute(SyntaxHighlighter.numberColor),
        numbers: attribute(SyntaxHighlighter.numberColor),
        strings: attribute(SyntaxHighlighter.stringColor),
        characters: attribute(SyntaxHighlighter.stringColor),
        comments: EditorTheme.Attribute(color: NSColor(SyntaxHighlighter.commentColor), italic: true))

    private static func attribute(_ color: Color) -> Attribute {
        Attribute(color: NSColor(color))
    }
}
