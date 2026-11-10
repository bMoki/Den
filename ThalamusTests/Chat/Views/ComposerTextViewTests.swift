import Testing
import AppKit
import SwiftUI
@testable import Thalamus

private let line = ComposerTextView.lineHeight

private func lines(_ height: CGFloat) -> Double {
    Double(height / line)
}

// MARK: - Height

@Test func anEmptyPromptIsOneLineTall() {
    #expect(lines(ComposerTextView.height(of: "", width: 400)) == 1)
}

@Test func eachLineAddsItsHeight() {
    #expect(lines(ComposerTextView.height(of: "a\nb\nc", width: 400)) == 3)
}

@Test func aTrailingNewlineOpensTheNextLine() {
    #expect(lines(ComposerTextView.height(of: "a\n", width: 400)) == 2)
}

@Test func aLongLineWrapsAtTheFieldWidth() {
    let text = String(repeating: "word ", count: 40)
    #expect(lines(ComposerTextView.height(of: text, width: 120)) > 1)
}

@Test func pastTheLastVisibleLineTheFieldStopsGrowing() {
    let text = (1...20).map(String.init).joined(separator: "\n")
    #expect(lines(ComposerTextView.height(of: text, width: 400))
            == Double(ComposerTextView.maxLines))
}

@Test func aHugeTextIsCappedToo() {
    let text = String(repeating: "x", count: 200_000)
    #expect(lines(ComposerTextView.height(of: text, width: 400))
            == Double(ComposerTextView.maxLines))
}

// MARK: - Paste

@MainActor
@Test func pastingHandsTheTextToTheChatFirst() {
    let board = NSPasteboard(name: .init("ThalamusTests-" + UUID().uuidString))
    defer { board.releaseGlobally() }
    board.clearContents()
    board.setString("pasted", forType: .string)

    let view = PromptTextView(usingTextLayoutManager: false)
    var offered: [String] = []
    view.onPaste = { offered.append($0); return true }

    #expect(view.capture(from: board))
    #expect(offered == ["pasted"])
}

@MainActor
@Test func aPasteTheChatDeclinesFallsThroughToTheField() {
    let board = NSPasteboard(name: .init("ThalamusTests-" + UUID().uuidString))
    defer { board.releaseGlobally() }
    board.clearContents()
    board.setString("short", forType: .string)

    let view = PromptTextView(usingTextLayoutManager: false)
    view.onPaste = { _ in false }

    #expect(view.capture(from: board) == false)
}

@MainActor
@Test func aPasteboardWithoutTextIsNotCaptured() {
    let board = NSPasteboard(name: .init("ThalamusTests-" + UUID().uuidString))
    defer { board.releaseGlobally() }
    board.clearContents()

    let view = PromptTextView(usingTextLayoutManager: false)
    view.onPaste = { _ in true }

    #expect(view.capture(from: board) == false)
}

@MainActor
private final class GhostLog {
    var accepted = 0
    var dismissed = 0
}

@MainActor
private func composer(ghost: String, log: GhostLog) -> ComposerTextView.Coordinator {
    ComposerTextView.Coordinator(ComposerTextView(
        text: .constant(""), focusRequested: .constant(false), placeholder: "",
        ghost: ghost, onSubmit: {}, onPaste: { _ in false },
        onAcceptGhost: { log.accepted += 1 }, onDismissGhost: { log.dismissed += 1 }))
}

@MainActor
@Test func theRightArrowInAnEmptyFieldAcceptsTheGhost() {
    let log = GhostLog()
    let handled = composer(ghost: "Sim", log: log)
        .textView(PromptTextView(usingTextLayoutManager: false),
                  doCommandBy: #selector(NSResponder.moveRight(_:)))
    #expect(handled)
    #expect(log.accepted == 1)
}

@MainActor
@Test func theRightArrowMovesTheCursorOnceTheFieldHasText() {
    let log = GhostLog()
    let field = PromptTextView(usingTextLayoutManager: false)
    field.string = "n"
    let handled = composer(ghost: "Sim", log: log)
        .textView(field, doCommandBy: #selector(NSResponder.moveRight(_:)))
    #expect(!handled)
    #expect(log.accepted == 0)
}

@MainActor
@Test func theRightArrowWithoutAGhostMovesTheCursor() {
    let log = GhostLog()
    let handled = composer(ghost: "", log: log)
        .textView(PromptTextView(usingTextLayoutManager: false),
                  doCommandBy: #selector(NSResponder.moveRight(_:)))
    #expect(!handled)
    #expect(log.accepted == 0)
}

@MainActor
@Test func escapeDismissesTheGhost() {
    let log = GhostLog()
    let handled = composer(ghost: "Sim", log: log)
        .textView(PromptTextView(usingTextLayoutManager: false),
                  doCommandBy: #selector(NSResponder.cancelOperation(_:)))
    #expect(handled)
    #expect(log.dismissed == 1)
}

@MainActor
private final class KeyLog {
    var taken = 0
    var older = 0
    var newer = 0
}

@MainActor
private func press(_ selector: Selector, in text: String, caret: Int? = nil, width: CGFloat = 400,
                   ghost: String = "", browsing: Bool = false, log: KeyLog) -> Bool {
    let field = ComposerTextView(
        text: .constant(text), focusRequested: .constant(false), placeholder: "",
        ghost: ghost, onSubmit: {}, onPaste: { _ in false },
        onTakeGhost: { log.taken += 1 },
        history: ComposerHistoryKeys(isBrowsing: browsing, canGoOlder: { true },
                                     older: { log.older += 1 }, newer: { log.newer += 1 }))
    let view = PromptTextView(usingTextLayoutManager: false)
    view.frame = NSRect(x: 0, y: 0, width: width, height: 200)
    view.textContainer?.lineFragmentPadding = 0
    view.textContainer?.widthTracksTextView = true
    view.font = ComposerTextView.font
    view.string = text
    view.setSelectedRange(NSRange(location: caret ?? (text as NSString).length, length: 0))
    return field.makeCoordinator().textView(view, doCommandBy: selector)
}

@MainActor
@Test func tabWithASuggestionTakesItIntoTheComposer() {
    let log = KeyLog()
    #expect(press(#selector(NSResponder.insertTab(_:)), in: "", ghost: "Sim", log: log))
    #expect(log.taken == 1)
}

@MainActor
@Test func tabWithoutASuggestionLeavesTheSuggestionAlone() {
    let log = KeyLog()
    #expect(press(#selector(NSResponder.insertTab(_:)), in: "texto", ghost: "Sim", log: log))
    #expect(press(#selector(NSResponder.insertTab(_:)), in: "", log: log))
    #expect(log.taken == 0)
}

@MainActor
@Test func upOnTheFirstLineRecallsTheHistory() {
    let log = KeyLog()
    #expect(press(#selector(NSResponder.moveUp(_:)), in: "", log: log))
    #expect(press(#selector(NSResponder.moveUp(_:)), in: "uma\nduas", caret: 2, log: log))
    #expect(log.older == 2)
}

@MainActor
@Test func upBelowTheFirstLineMovesTheCaretFirst() {
    let log = KeyLog()
    #expect(!press(#selector(NSResponder.moveUp(_:)), in: "uma\nduas", log: log))
    #expect(!press(#selector(NSResponder.moveUp(_:)), in: "uma\n", log: log))
    let wrapped = String(repeating: "palavra ", count: 30)
    #expect(!press(#selector(NSResponder.moveUp(_:)), in: wrapped, width: 120, log: log))
    #expect(log.older == 0)
}

@MainActor
@Test func downOnTheLastLineGoesForwardOnlyWhileBrowsing() {
    let log = KeyLog()
    #expect(!press(#selector(NSResponder.moveDown(_:)), in: "uma", log: log))
    #expect(!press(#selector(NSResponder.moveDown(_:)), in: "uma\nduas", caret: 0, browsing: true, log: log))
    #expect(press(#selector(NSResponder.moveDown(_:)), in: "uma\nduas", browsing: true, log: log))
    #expect(log.newer == 1)
}
