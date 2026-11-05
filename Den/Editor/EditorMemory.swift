import AppKit
import CodeEditSourceEditor
import CodeEditTextView

final class EditorMemory: TextViewCoordinator {
    let undoManager = CEUndoManager()
    private var scroll: CGPoint?

    func prepareCoordinator(controller: TextViewController) {}

    func controllerDidAppear(controller: TextViewController) {
        guard let scroll else { return }
        Self.restore(scroll, in: controller)
        DispatchQueue.main.async { [weak controller] in
            if let controller { Self.restore(scroll, in: controller) }
        }
    }

    func controllerDidDisappear(controller: TextViewController) {
        scroll = controller.scrollView.contentView.bounds.origin
    }

    func keep(_ scroll: CGPoint?) {
        if let scroll { self.scroll = scroll }
    }

    func recordReplacement(of old: String, with new: String) {
        let change = Self.change(from: old, to: new)
        let view = TextView(string: old)
        view.setUndoManager(undoManager)
        undoManager.beginUndoGrouping()
        view.replaceCharacters(in: [change.range], with: change.replacement)
        undoManager.endUndoGrouping()
    }

    nonisolated static func change(from old: String, to new: String) -> (range: NSRange, replacement: String) {
        let old = old as NSString
        let new = new as NSString
        let shortest = min(old.length, new.length)
        var prefix = 0
        while prefix < shortest, old.character(at: prefix) == new.character(at: prefix) { prefix += 1 }
        var suffix = 0
        while suffix < shortest - prefix, old.character(at: old.length - 1 - suffix) == new.character(at: new.length - 1 - suffix) {
            suffix += 1
        }
        let replaced = NSRange(location: prefix, length: new.length - prefix - suffix)
        return (NSRange(location: prefix, length: old.length - prefix - suffix), new.substring(with: replaced))
    }

    nonisolated static func moved(_ position: CursorPosition.Position, from old: String, to new: String) -> CursorPosition.Position {
        let change = change(from: old, to: new)
        let offset = offset(of: position, in: old as NSString)
        let shifted = if offset > change.range.location, offset >= change.range.location + change.range.length {
            offset + (change.replacement as NSString).length - change.range.length
        } else {
            min(offset, change.range.location)
        }
        return Self.position(of: shifted, in: new as NSString)
    }

    private nonisolated static func offset(of position: CursorPosition.Position, in text: NSString) -> Int {
        var start = 0
        for _ in 1..<max(position.line, 1) {
            guard let next = nextLine(after: start, in: text) else { return text.length }
            start = next
        }
        let line = text.lineRange(for: NSRange(location: start, length: 0))
        return min(start + max(position.column - 1, 0), line.location + line.length)
    }

    private nonisolated static func position(of offset: Int, in text: NSString) -> CursorPosition.Position {
        var line = 1
        var start = 0
        while let next = nextLine(after: start, in: text), next <= offset {
            start = next
            line += 1
        }
        return CursorPosition.Position(line: line, column: offset - start + 1)
    }

    private nonisolated static func nextLine(after start: Int, in text: NSString) -> Int? {
        guard start < text.length else { return nil }
        let line = text.lineRange(for: NSRange(location: start, length: 0))
        let end = line.location + line.length
        let last = text.character(at: end - 1)
        return last == 0x0A || last == 0x0D ? end : nil
    }

    private static func restore(_ scroll: CGPoint, in controller: TextViewController) {
        guard let scrollView = controller.scrollView else { return }
        controller.textView.updateFrameIfNeeded()
        scrollView.contentView.scroll(to: scroll)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }
}
