import SwiftUI
import Testing
@testable import Den

@Test func theTreeKeysMatchThePrototypeShortcuts() {
    #expect(FileTreeShortcut(key: .downArrow, characters: "", modifiers: []) == .next)
    #expect(FileTreeShortcut(key: .upArrow, characters: "", modifiers: .numericPad) == .previous)
    #expect(FileTreeShortcut(key: .rightArrow, characters: "", modifiers: []) == .open)
    #expect(FileTreeShortcut(key: .leftArrow, characters: "", modifiers: []) == .close)
    #expect(FileTreeShortcut(key: .return, characters: "\r", modifiers: []) == .rename)
    #expect(FileTreeShortcut(key: .delete, characters: "\u{7F}", modifiers: .command) == .trash)
    #expect(FileTreeShortcut(key: "ç", characters: "ç", modifiers: [.command, .option]) == .copyPath)
    #expect(FileTreeShortcut(key: "c", characters: "c", modifiers: [.command, .option]) == .copyPath)
}

@Test func otherKeysAreLeftForTheRestOfTheApp() {
    #expect(FileTreeShortcut(key: .delete, characters: "\u{7F}", modifiers: []) == nil)
    #expect(FileTreeShortcut(key: "c", characters: "c", modifiers: .command) == nil)
    #expect(FileTreeShortcut(key: .return, characters: "\r", modifiers: .command) == nil)
    #expect(FileTreeShortcut(key: .downArrow, characters: "", modifiers: .shift) == nil)
    #expect(FileTreeShortcut(key: "a", characters: "a", modifiers: []) == nil)
}

@Test func theMenuShowsTheShortcutsItCanRun() {
    #expect(FileTreeShortcut.rename.hint == "↩")
    #expect(FileTreeShortcut.copyPath.hint == "⌥⌘C")
    #expect(FileTreeShortcut.trash.hint == "⌘⌫")
    #expect(FileTreeShortcut.next.hint == nil)
}
