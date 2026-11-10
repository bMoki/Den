import Foundation
import HarnessCore
@testable import Thalamus

private func chatRoot() -> URL {
    FileManager.default.temporaryDirectory.appending(path: "ThalamusTests-" + UUID().uuidString)
}

func inertChat() -> ChatModel {
    let root = chatRoot()
    return ChatModel(store: FileTranscriptStore(root: root),
                     workingDirectory: root,
                     harness: HarnessID(rawValue: "test-" + UUID().uuidString),
                     cache: scratchCache, attachmentsRoot: root.appending(path: "attachments"))
}

func chatRestoring(_ entries: [TranscriptEntry] = [], context: ContextUsage? = nil) -> ChatModel {
    let root = chatRoot()
    let segment = Segment(harness: HarnessID(rawValue: "test-" + UUID().uuidString),
                          harnessSessionID: "", model: "", entries: entries, context: context)
    let session = Session(title: "restored", workingDirectory: root, segments: [segment])
    return ChatModel(store: FileTranscriptStore(root: root), restoring: session, cache: scratchCache,
                     attachmentsRoot: root.appending(path: "attachments"))
}
