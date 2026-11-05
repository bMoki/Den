import Foundation
import Testing
@testable import Den

@MainActor
private func twoWindows() throws -> (EditorWindows, [EditorTabs], URL) {
    let windows = EditorWindows()
    return (windows, [EditorTabs(windows: windows), EditorTabs(windows: windows)], try makeTree([], files: ["a.ts", "b.ts"]))
}

@Test @MainActor func everyOpenWindowIsAskedAboutWhenLeaving() async throws {
    let (windows, tabs, root) = try twoWindows()
    defer { try? FileManager.default.removeItem(at: root) }
    let session = UUID()
    let a = try await loaded(tabs[0], ["a.ts"], in: session, root: root)
    let b = try await loaded(tabs[1], ["b.ts"], in: session, root: root)
    a[0].text = "mine\n"
    b[0].text = "mine\n"

    #expect(Set(windows.unsaved().map(\.name)) == ["a.ts", "b.ts"])
    #expect(!windows.settle(.cancel))
    #expect(windows.settle(.saveAll))
    #expect(windows.unsaved().isEmpty)

    windows.closeSession(session)
    #expect(tabs[0].documents(in: session).isEmpty)
    #expect(tabs[1].documents(in: session).isEmpty)
}

@Test @MainActor func theSameFileInTwoWindowsIsOneTextAskedAboutOnce() async throws {
    let (windows, tabs, root) = try twoWindows()
    defer { try? FileManager.default.removeItem(at: root) }
    let a = try await loaded(tabs[0], ["a.ts", "b.ts"], in: UUID(), root: root)
    let again = try await loaded(tabs[1], ["a.ts"], in: UUID(), root: root)
    a.forEach { $0.text = "mine\n" }

    #expect(again.first === a[0])
    #expect(windows.unsaved().map(\.name).sorted() == ["a.ts", "b.ts"])
    #expect(tabs[0].unsaved().map(\.name) == ["b.ts"])
    #expect(tabs[1].unsaved().isEmpty)
    #expect(windows.settle(.saveAll))
    #expect(try String(contentsOf: a[0].url, encoding: .utf8) == "mine\n")
    #expect(a[0].changedOnDisk == nil)
}
