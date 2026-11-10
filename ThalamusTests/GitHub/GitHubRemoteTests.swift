import Testing
import Foundation
@testable import Thalamus

private let expected = GitHubRemote(host: "github.com", owner: "thalamus", name: "app")

@Test func httpsRemotesAreRead() {
    #expect(GitHubRemote(remoteURL: "https://github.com/thalamus/app.git") == expected)
    #expect(GitHubRemote(remoteURL: "https://github.com/thalamus/app") == expected)
    #expect(GitHubRemote(remoteURL: "http://GitHub.com/thalamus/app\n") == expected)
}

@Test func sshRemotesAreRead() {
    #expect(GitHubRemote(remoteURL: "git@github.com:thalamus/app.git") == expected)
    #expect(GitHubRemote(remoteURL: "ssh://git@github.com/thalamus/app") == expected)
    #expect(GitHubRemote(remoteURL: "ssh://git@github.com:22/thalamus/app.git") == expected)
}

@Test func anEnterpriseHostIsKept() {
    #expect(GitHubRemote(remoteURL: "git@git.acme.com:thalamus/app.git")
            == GitHubRemote(host: "git.acme.com", owner: "thalamus", name: "app"))
}

@Test func localAndMalformedRemotesAreNotGitHub() {
    #expect(GitHubRemote(remoteURL: "../origin.git") == nil)
    #expect(GitHubRemote(remoteURL: "/tmp/origin.git") == nil)
    #expect(GitHubRemote(remoteURL: "file:///tmp/origin.git") == nil)
    #expect(GitHubRemote(remoteURL: "https://github.com/onlyowner") == nil)
}
