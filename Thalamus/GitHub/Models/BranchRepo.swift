import Foundation

nonisolated struct BranchRepo: Hashable, Sendable, Identifiable {
    nonisolated struct Key: Hashable, Codable, Sendable {
        let branch: String
        let repo: String
    }

    let branch: String
    let name: String
    let folder: URL
    let remote: GitHubRemote?
    let gitBranch: String?

    var id: Key { Key(branch: branch, repo: name) }

    static func list(in status: NsStatus) -> [BranchRepo] {
        let remotes = status.baseRepos.map { GitHubRemote(originOf: URL(fileURLWithPath: $0.path)) }
        return status.branches.flatMap { branch in
            zip(status.baseRepos, remotes).compactMap { base, remote in
                let folder = URL(fileURLWithPath: branch.path).appending(path: base.repo)
                guard FileManager.default.fileExists(atPath: folder.appending(path: ".git").path) else { return nil }
                return BranchRepo(branch: branch.branch, name: base.repo, folder: folder, remote: remote,
                                  gitBranch: branch.gitBranch(of: base.repo))
            }
        }
    }
}
