import Testing
import Foundation
@testable import Thalamus

private struct Scene {
    let root: URL
    let den: ScratchDefaults
    let thalamus: ScratchDefaults
    let migration: DenMigration

    var denFolder: URL { migration.denFolder }
    var folder: URL { migration.folder }

    func remove() {
        den.remove()
        thalamus.remove()
        try? FileManager.default.removeItem(at: root)
    }
}

private func scene() throws -> Scene {
    let root = try makeTree([])
    let den = ScratchDefaults()
    return Scene(root: root, den: den, thalamus: ScratchDefaults(),
                 migration: DenMigration(denFolder: root.appending(path: "Den"),
                                         denDomain: den.suite,
                                         folder: root.appending(path: "Thalamus")))
}

private func write(_ text: String, to file: URL) throws {
    try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try text.write(to: file, atomically: true, encoding: .utf8)
}

private func read(_ file: URL) -> String? {
    try? String(contentsOf: file, encoding: .utf8)
}

@Test func theFirstLaunchCopiesTheDenDataAndPreferences() throws {
    let scene = try scene()
    defer { scene.remove() }
    try write("{}", to: scene.denFolder.appending(path: "sessions/one/session.json"))
    try write("[]", to: scene.denFolder.appending(path: "pull-requests.json"))
    scene.den.defaults.set("/opt/ns", forKey: "Den.nsPath")
    scene.den.defaults.set(["a", "b"], forKey: "Den.sessionOpenings")
    scene.den.defaults.set("left out", forKey: "NSWindow Frame main")

    scene.migration.run(into: scene.thalamus.defaults)

    #expect(read(scene.folder.appending(path: "sessions/one/session.json")) == "{}")
    #expect(read(scene.folder.appending(path: "pull-requests.json")) == "[]")
    #expect(scene.thalamus.defaults.string(forKey: "Thalamus.nsPath") == "/opt/ns")
    #expect(scene.thalamus.defaults.stringArray(forKey: "Thalamus.sessionOpenings") == ["a", "b"])
    #expect(scene.thalamus.defaults.object(forKey: "Den.nsPath") == nil)
    #expect(scene.thalamus.defaults.object(forKey: "NSWindow Frame main") == nil)
}

@Test func theDenDataIsLeftAsItWas() throws {
    let scene = try scene()
    defer { scene.remove() }
    let attachment = scene.denFolder.appending(path: "attachments/a.png").path
    let session = scene.denFolder.appending(path: "sessions/one/segment.jsonl")
    try write(#"{"path":"\#(attachment)"}"#, to: session)
    scene.den.defaults.set("/opt/ns", forKey: "Den.nsPath")

    scene.migration.run(into: scene.thalamus.defaults)

    #expect(read(session) == #"{"path":"\#(attachment)"}"#)
    #expect(scene.den.defaults.string(forKey: "Den.nsPath") == "/opt/ns")
    #expect(scene.den.defaults.object(forKey: "Thalamus.nsPath") == nil)
}

@Test func copiedSessionsPointAtTheCopiedAttachments() throws {
    let scene = try scene()
    defer { scene.remove() }
    let denAttachment = scene.denFolder.appending(path: "attachments/a.png").path
    try write("png", to: URL(fileURLWithPath: denAttachment))
    try write(#"{"path":"\#(denAttachment)"}"#, to: scene.denFolder.appending(path: "sessions/one/segment.jsonl"))

    scene.migration.run(into: scene.thalamus.defaults)

    let attachment = scene.folder.appending(path: "attachments/a.png").path
    #expect(read(scene.folder.appending(path: "sessions/one/segment.jsonl")) == #"{"path":"\#(attachment)"}"#)
    #expect(read(URL(fileURLWithPath: attachment)) == "png")
}

@Test func theMigrationRunsOnlyOnce() throws {
    let scene = try scene()
    defer { scene.remove() }
    try write("{}", to: scene.denFolder.appending(path: "sessions/one/session.json"))
    scene.den.defaults.set("/opt/ns", forKey: "Den.nsPath")
    scene.migration.run(into: scene.thalamus.defaults)

    scene.thalamus.defaults.set("/changed/ns", forKey: "Thalamus.nsPath")
    try FileManager.default.removeItem(at: scene.folder.appending(path: "sessions/one"))
    scene.migration.run(into: scene.thalamus.defaults)

    #expect(scene.thalamus.defaults.string(forKey: "Thalamus.nsPath") == "/changed/ns")
    #expect(!FileManager.default.fileExists(atPath: scene.folder.appending(path: "sessions/one").path))
}

@Test func withoutDenDataThalamusStartsEmpty() throws {
    let scene = try scene()
    defer { scene.remove() }

    scene.migration.run(into: scene.thalamus.defaults)

    #expect(try FileManager.default.contentsOfDirectory(atPath: scene.folder.path).isEmpty)
    #expect(scene.thalamus.defaults.dictionaryRepresentation().keys.allSatisfy { !$0.hasPrefix("Thalamus.") })
    #expect(try FileManager.default.contentsOfDirectory(atPath: scene.root.path) == ["Thalamus"])
}

@Test func denDataThatAppearsLaterIsNotCopied() throws {
    let scene = try scene()
    defer { scene.remove() }
    scene.migration.run(into: scene.thalamus.defaults)

    try write("{}", to: scene.denFolder.appending(path: "sessions/one/session.json"))
    scene.den.defaults.set("/opt/ns", forKey: "Den.nsPath")
    scene.migration.run(into: scene.thalamus.defaults)

    #expect(!FileManager.default.fileExists(atPath: scene.folder.appending(path: "sessions").path))
    #expect(scene.thalamus.defaults.object(forKey: "Thalamus.nsPath") == nil)
}

@Test func aThalamusPreferenceSetBeforeTheFirstLaunchWins() throws {
    let scene = try scene()
    defer { scene.remove() }
    scene.den.defaults.set("/den/ns", forKey: "Den.nsPath")
    scene.den.defaults.set("/den/config", forKey: "Den.nsConfigDir")
    scene.thalamus.defaults.set("/dev/ns", forKey: "Thalamus.nsPath")

    scene.migration.run(into: scene.thalamus.defaults)

    #expect(scene.thalamus.defaults.string(forKey: "Thalamus.nsPath") == "/dev/ns")
    #expect(scene.thalamus.defaults.string(forKey: "Thalamus.nsConfigDir") == "/den/config")
}

@Test func aStagingCopyLeftByACrashIsReplaced() throws {
    let scene = try scene()
    defer { scene.remove() }
    let staging = scene.root.appending(path: ".Thalamus-migrating")
    try write("stale", to: staging.appending(path: "sessions/old/session.json"))
    try write("{}", to: scene.denFolder.appending(path: "sessions/one/session.json"))

    scene.migration.run(into: scene.thalamus.defaults)

    #expect(read(scene.folder.appending(path: "sessions/one/session.json")) == "{}")
    #expect(!FileManager.default.fileExists(atPath: scene.folder.appending(path: "sessions/old").path))
    #expect(!FileManager.default.fileExists(atPath: staging.path))
}

@Test func aDenFolderBehindASymlinkIsCopiedNotRewritten() throws {
    let scene = try scene()
    defer { scene.remove() }
    let real = scene.root.appending(path: "RealDen")
    let attachment = scene.denFolder.appending(path: "attachments/a.png").path
    let session = real.appending(path: "sessions/one/segment.jsonl")
    try write(#"{"path":"\#(attachment)"}"#, to: session)
    try FileManager.default.createSymbolicLink(at: scene.denFolder, withDestinationURL: real)

    scene.migration.run(into: scene.thalamus.defaults)

    let copied = scene.folder.appending(path: "sessions/one/segment.jsonl")
    #expect(read(session) == #"{"path":"\#(attachment)"}"#)
    #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: scene.folder.path)) == nil)
    #expect(read(copied) == #"{"path":"\#(scene.folder.appending(path: "attachments/a.png").path)"}"#)
}
