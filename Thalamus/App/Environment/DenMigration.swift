import Foundation

nonisolated struct DenMigration: Equatable {
    static let denPrefix = "Den."

    let denFolder: URL
    let denDomain: String
    let folder: URL

    func run(into defaults: UserDefaults) {
        let files = FileManager.default
        guard !files.fileExists(atPath: folder.path) else { return }
        copyPreferences(into: defaults)
        try? files.createDirectory(at: folder.deletingLastPathComponent(), withIntermediateDirectories: true)
        let source = denFolder.resolvingSymlinksInPath()
        if files.fileExists(atPath: source.path) {
            copy(source)
        }
        try? files.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    private func copy(_ source: URL) {
        let files = FileManager.default
        let staging = folder.deletingLastPathComponent().appending(path: ".\(folder.lastPathComponent)-migrating")
        try? files.removeItem(at: staging)
        do {
            try files.copyItem(at: source, to: staging)
            repointAttachments(in: staging)
            try files.moveItem(at: staging, to: folder)
        } catch {
            try? files.removeItem(at: staging)
            NSLog("Thalamus could not copy %@ to %@: %@", source.path, folder.path, String(describing: error))
        }
    }

    private func copyPreferences(into defaults: UserDefaults) {
        let preferences = UserDefaults.standard.persistentDomain(forName: denDomain) ?? [:]
        for (key, value) in preferences where key.hasPrefix(Self.denPrefix) {
            let renamed = PreferenceKey.named(String(key.dropFirst(Self.denPrefix.count)))
            if defaults.object(forKey: renamed) == nil {
                defaults.set(value, forKey: renamed)
            }
        }
    }

    private func repointAttachments(in copy: URL) {
        let old = denFolder.appending(path: "attachments").path + "/"
        let new = folder.appending(path: "attachments").path + "/"
        let sessions = copy.appending(path: "sessions")
        guard let walk = FileManager.default.enumerator(at: sessions, includingPropertiesForKeys: [.isRegularFileKey])
        else { return }
        for case let file as URL in walk {
            guard (try? file.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true,
                  let text = try? String(contentsOf: file, encoding: .utf8), text.contains(old) else { continue }
            try? text.replacingOccurrences(of: old, with: new).write(to: file, atomically: true, encoding: .utf8)
        }
    }
}
