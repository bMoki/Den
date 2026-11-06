import AppKit
import Foundation
import Observation
import HarnessCore

@MainActor
@Observable
final class WorkspaceModel {
    var summaries: [SessionSummary] = []
    var selectedID: UUID?
    var search: String = ""

    var workingDirectory: URL = URL(fileURLWithPath: NSHomeDirectory())

    var defaultHarness: HarnessID {
        get { registry.preferred(in: defaults) }
        set { registry.setPreferred(newValue, in: defaults) }
    }

    var availableHarnesses: [HarnessID] { registry.ids }

    private let store: FileTranscriptStore
    private let defaults: UserDefaults
    private let cache: SessionCache
    private let registry: HarnessRegistry
    private let attachmentsRoot: URL
    private var chats: [UUID: ChatModel] = [:]

    static func live(_ environment: any AppEnvironment) -> WorkspaceModel {
        let root = environment.sessionsRoot
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let workspace = WorkspaceModel(store: FileTranscriptStore(root: root),
                                       defaults: environment.defaults,
                                       cache: SessionCache(defaults: environment.defaults),
                                       registry: environment.registry,
                                       attachmentsRoot: environment.attachmentsRoot)
        workspace.workingDirectory = environment.workingDirectory
        return workspace
    }

    init(store: FileTranscriptStore, defaults: UserDefaults, cache: SessionCache,
         registry: HarnessRegistry = .standard,
         attachmentsRoot: URL = ChatModel.standardAttachmentsRoot) {
        self.store = store
        self.defaults = defaults
        self.cache = cache
        self.registry = registry
        self.attachmentsRoot = attachmentsRoot
    }

    func renameSession(_ id: UUID, to title: String) async {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var session = try? await store.load(id) else { return }
        session.title = trimmed
        try? await store.saveMetadata(session)
        chats[id]?.adoptTitle(trimmed)
        await refresh()
    }

    var active: ChatModel? {
        guard let selectedID else { return nil }
        return chats[selectedID]
    }

    func isLive(_ id: UUID) -> Bool {
        chats[id]?.isLive ?? false
    }

    func state(for id: UUID) -> SessionState? {
        chats[id]?.sessionState
    }

    private func adopt(_ chat: ChatModel) {
        let id = chat.sessionID
        chat.isViewed = { [weak self] in
            self?.selectedID == id && NSApplication.shared.isActive
        }
        chat.metadataDidChange = { [weak self] in
            Task { @MainActor in await self?.refresh() }
        }
    }

    // MARK: - Actions

    func refresh() async {
        guard let listing = try? await store.list() else { return }
        summaries = listing.sessions

        for broken in listing.unreadable {
            print("sessão ilegível em \(broken.location.path): \(broken.reason)")
        }
    }

    func newSession(in directory: URL? = nil, harness: HarnessID? = nil) async {
        if let directory {
            workingDirectory = directory
        } else if let selectedID,
                  let summary = summaries.first(where: { $0.id == selectedID }) {
            workingDirectory = summary.workingDirectory
        }
        let chat = ChatModel(store: store, workingDirectory: workingDirectory,
                             harness: harness ?? defaultHarness, cache: cache,
                             registry: registry, attachmentsRoot: attachmentsRoot)
        adopt(chat)
        await chat.persistMetadata()
        chats[chat.sessionID] = chat
        selectedID = chat.sessionID
        await refresh()
        await chat.start()
    }

    func select(_ id: UUID) async {
        selectedID = id
        if let chat = chats[id] {
            if chat.hasUnread { chat.hasUnread = false }
            return
        }
        guard let session = try? await store.load(id) else { return }
        let chat = ChatModel(store: store, restoring: session, cache: cache,
                             registry: registry, attachmentsRoot: attachmentsRoot)
        adopt(chat)
        chats[id] = chat
    }

    func deleteSession(_ id: UUID) async {
        if let chat = chats[id] { await chat.stop() }
        chats[id] = nil
        if selectedID == id { selectedID = nil }
        try? await store.delete(id)
        await refresh()
    }

    func stopAll() async {
        for chat in chats.values { await chat.stop() }
    }
}
