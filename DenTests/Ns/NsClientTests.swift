import Foundation
import HarnessCore
import Testing
@testable import Den

private func fakeNs(_ script: String) throws -> (client: NsClient, folder: URL) {
    let folder = FileManager.default.temporaryDirectory.appending(path: "FakeNs-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let executable = folder.appending(path: "ns")
    try ("#!/bin/sh\n" + script).write(to: executable, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
    let client = NsClient(timeout: .seconds(2)) {
        ProcessTransport.Launch(executable: executable.path, arguments: ["rpc"], workingDirectory: folder)
    }
    return (client, folder)
}

private let answersStatus = #"""
    echo '{"type":"ready","protocol":1,"ops":["status"]}'
    while read -r line; do
        id=$(printf '%s\n' "$line" | sed -n 's/.*"id":"\([^"]*\)".*/\1/p')
        echo "{\"type\":\"event\",\"id\":\"$id\",\"event\":{\"step\":\"status:branch\",\"label\":\"x\"}}"
        branch="{\"branch\":\"b$id\",\"path\":\"/w/b$id\"}"
        echo "{\"type\":\"result\",\"id\":\"$id\",\"result\":{\"baseRepos\":[],\"branches\":[$branch]}}"
    done
    """#

@Test func statusComesBackFromTheRpcProcess() async throws {
    let (client, folder) = try fakeNs(answersStatus)
    defer { try? FileManager.default.removeItem(at: folder) }

    let status = try await client.status()
    #expect(status.branches.map(\.branch) == ["b1"])
}

@Test func oneProcessServesRequestsInParallel() async throws {
    let (client, folder) = try fakeNs(answersStatus)
    defer { try? FileManager.default.removeItem(at: folder) }

    async let first = client.status()
    async let second = client.status()
    let names = try await Set([first, second].flatMap { $0.branches.map(\.branch) })
    #expect(names == ["b1", "b2"])
}

@Test func concurrentFirstRequestsShareOneProcess() async throws {
    let (client, folder) = try fakeNs("echo started >> \"$0.launches\"\n" + answersStatus)
    defer { try? FileManager.default.removeItem(at: folder) }

    async let first = client.status()
    async let second = client.status()
    _ = try await (first, second)
    let launches = try String(contentsOf: folder.appending(path: "ns.launches"), encoding: .utf8)
    #expect(launches.split(separator: "\n").count == 1)
}

@Test func anErrorReplyCarriesTheNsMessage() async throws {
    let (client, folder) = try fakeNs(#"""
        read -r line
        echo '{"type":"error","id":"1","error":{"category":"pre-condicao","message":"workspace não configurado"}}'
        cat >/dev/null
        """#)
    defer { try? FileManager.default.removeItem(at: folder) }

    await #expect(throws: NsFailure(message: "workspace não configurado")) { try await client.status() }
}

@Test func anNsWithoutRpcFailsWithWhatItPrinted() async throws {
    let (client, folder) = try fakeNs("echo \"error: unknown command 'rpc'\" >&2\nexit 1\n")
    defer { try? FileManager.default.removeItem(at: folder) }

    await #expect(throws: NsFailure(message: "o ns rpc saiu: error: unknown command 'rpc'")) {
        try await client.status()
    }
}

@Test func aSilentNsTimesOut() async throws {
    let (client, folder) = try fakeNs("cat >/dev/null\n")
    defer { try? FileManager.default.removeItem(at: folder) }

    await #expect(throws: NsFailure(message: "o ns rpc não respondeu a tempo")) { try await client.status() }
}

@Test func theNextRequestStartsANewProcessAfterOneDies() async throws {
    let (client, folder) = try fakeNs(#"""
        if [ ! -e "$0.ran" ]; then touch "$0.ran"; exit 3; fi

        """# + answersStatus)
    defer { try? FileManager.default.removeItem(at: folder) }

    await #expect(throws: NsFailure(message: "o ns rpc saiu com código 3")) { try await client.status() }
    #expect(try await client.status().branches.map(\.branch) == ["b2"])
}

@Test func aHungNsIsReplacedByAFreshProcess() async throws {
    let (client, folder) = try fakeNs(#"""
        if [ ! -e "$0.ran" ]; then touch "$0.ran"; exec cat >/dev/null; fi

        """# + answersStatus)
    defer { try? FileManager.default.removeItem(at: folder) }

    await #expect(throws: NsFailure(message: "o ns rpc não respondeu a tempo")) { try await client.status() }
    #expect(try await client.status().branches.map(\.branch) == ["b2"])
}

@Test func withAnOverrideOnlyThatPathIsTried() async throws {
    let client = NsClient.locating(override: "/nonexistent/ns")
    await #expect(throws: NsFailure(message: "ns não encontrado no PATH")) { try await client.status() }
}
