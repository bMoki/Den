import SwiftUI

nonisolated enum FileTreeShortcut: Equatable {
    case next
    case previous
    case open
    case close
    case rename
    case copyPath
    case trash

    init?(key: KeyEquivalent, characters: String, modifiers: EventModifiers) {
        switch (key, modifiers.intersection([.command, .option, .control, .shift])) {
        case (.downArrow, []): self = .next
        case (.upArrow, []): self = .previous
        case (.rightArrow, []): self = .open
        case (.leftArrow, []): self = .close
        case (.return, []): self = .rename
        case (.delete, .command): self = .trash
        case (_, [.command, .option]) where key == "c" || ["c", "ç"].contains(characters.lowercased()): self = .copyPath
        default: return nil
        }
    }

    var hint: String? {
        switch self {
        case .rename: "↩"
        case .copyPath: "⌥⌘C"
        case .trash: "⌘⌫"
        case .next, .previous, .open, .close: nil
        }
    }
}
