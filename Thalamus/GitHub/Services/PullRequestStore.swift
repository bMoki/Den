import Foundation

nonisolated struct PullRequestStore: Sendable {
    let url: URL

    struct Entry: Codable, Equatable, Sendable {
        var pullRequest: PullRequest?
        var dismissed: String?
    }

    private struct File: Codable {
        var version: Int
        var branches: [String: [String: Entry]]
    }

    func load() -> [BranchRepo.Key: Entry] {
        guard let data = try? Data(contentsOf: url) else { return [:] }
        do {
            let branches = try JSONDecoder().decode(File.self, from: data).branches
            return Dictionary(uniqueKeysWithValues: branches.flatMap { branch, repos in
                repos.map { (BranchRepo.Key(branch: branch, repo: $0.key), $0.value) }
            })
        } catch {
            UnreadableFile.setAside(url, holding: "PRs das branches", because: error)
            return [:]
        }
    }

    func save(_ entries: [BranchRepo.Key: Entry]) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        var branches: [String: [String: Entry]] = [:]
        for (key, entry) in entries { branches[key.branch, default: [:]][key.repo] = entry }
        try encoder.encode(File(version: 1, branches: branches)).write(to: url, options: .atomic)
    }
}
