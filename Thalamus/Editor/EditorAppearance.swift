import AppKit
import CodeEditSourceEditor
import SwiftUI

extension SourceEditorConfiguration {
    static let thalamus = SourceEditorConfiguration(
        appearance: .init(theme: .thalamus, font: Theme.nsCodeFont(.smallPlus),
                           lineHeightMultiple: Theme.style.codeLineHeight, wrapLines: false),
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
        keywords: attribute(Theme.palette.syntax.keyword),
        commands: attribute(Theme.palette.syntax.command),
        types: attribute(Theme.palette.syntax.type),
        attributes: attribute(Theme.palette.syntax.attribute),
        variables: attribute(Theme.text),
        values: attribute(Theme.palette.syntax.number),
        numbers: attribute(Theme.palette.syntax.number),
        strings: attribute(Theme.palette.syntax.string),
        characters: attribute(Theme.palette.syntax.string),
        comments: EditorTheme.Attribute(color: NSColor(Theme.palette.syntax.comment), italic: true))

    private static func attribute(_ color: Color) -> Attribute {
        Attribute(color: NSColor(color))
    }
}
