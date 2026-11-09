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
    let row = anyRow()
    let a = try await loaded(tabs[0], ["a.ts"], in: row, root: root)
    let b = try await loaded(tabs[1], ["b.ts"], in: row, root: root)
    a[0].text = "mine\n"
    b[0].text = "mine\n"

    #expect(Set(windows.unsaved().map(\.name)) == ["a.ts", "b.ts"])
    #expect(!windows.settle(.cancel))
    #expect(windows.settle(.saveAll))
    #expect(windows.unsaved().isEmpty)

    windows.close(row)
    #expect(tabs[0].documents(in: row).isEmpty)
    #expect(tabs[1].documents(in: row).isEmpty)
}

@Test @MainActor func theSameFileInTwoWindowsIsOneTextAskedAboutOnce() async throws {
    let (windows, tabs, root) = try twoWindows()
    defer { try? FileManager.default.removeItem(at: root) }
    let a = try await loaded(tabs[0], ["a.ts", "b.ts"], in: anyRow(), root: root)
    let again = try await loaded(tabs[1], ["a.ts"], in: anyRow(), root: root)
    a.forEach { $0.text = "mine\n" }

    #expect(again.first === a[0])
    #expect(windows.unsaved().map(\.name).sorted() == ["a.ts", "b.ts"])
    #expect(tabs[0].unsaved().map(\.name) == ["b.ts"])
    #expect(tabs[1].unsaved().isEmpty)
    #expect(windows.settle(.saveAll))
    #expect(try String(contentsOf: a[0].url, encoding: .utf8) == "mine\n")
    #expect(a[0].changedOnDisk == nil)
}

@Test @MainActor func everySessionOfARowSeesTheSameTabsAndOnlyItsUnsavedOnes() async throws {
    let (windows, tabs, root) = try twoWindows()
    defer { try? FileManager.default.removeItem(at: root) }
    let row = SidebarRow.branch("NS-1")
    let documents = try await loaded(tabs[0], ["a.ts", "b.ts"], in: row, root: root)
    _ = try await loaded(tabs[0], ["b.ts"], in: anyRow(), root: root)
    documents[0].text = "mine\n"

    #expect(tabs[0].documents(in: row).map(\.name) == ["a.ts", "b.ts"])
    #expect(tabs[0].selection(in: row)?.name == "b.ts")
    #expect(windows.unsaved(in: row).map(\.name) == ["a.ts"])
    #expect(windows.unsaved(in: .branch("NS-2")).isEmpty)
}
