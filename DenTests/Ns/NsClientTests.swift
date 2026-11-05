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

@Test func startSendsTheBranchAndReportsEachStep() async throws {
    let (client, folder) = try fakeNs(#"""
        echo '{"type":"ready","protocol":1,"ops":["start"]}'
        read -r line
        printf '%s\n' "$line" > "$0.request"
        echo '{"type":"event","id":"1","event":{"step":"database:start","label":"Iniciando PostgreSQL..."}}'
        echo '{"type":"event","id":"1","event":{"step":"start:backend","label":"Iniciando Backend..."}}'
        echo '{"type":"result","id":"1","result":{"branch":"NS-1","services":[]}}'
        cat >/dev/null
        """#)
    defer { try? FileManager.default.removeItem(at: folder) }

    let labels = Recorder()
    try await client.start(branch: "NS-1") { labels.append($0) }

    let request = try String(contentsOf: folder.appending(path: "ns.request"), encoding: .utf8)
    #expect(request.contains(#""op":"start""#))
    #expect(request.contains(#""branch":"NS-1""#))
    #expect(request.contains(#""installMissingDeps":"always""#))
    #expect(!request.contains(#""service""#))
    #expect(labels.all == ["Iniciando PostgreSQL...", "Iniciando Backend..."])
}

@Test func aSlowStatusDoesNotKillAStartInFlight() async throws {
    let (client, folder) = try fakeNs(#"""
        read -r start
        read -r status
        sleep 3
        echo '{"type":"result","id":"1","result":{}}'
        cat >/dev/null
        """#)
    defer { try? FileManager.default.removeItem(at: folder) }

    async let started: Void = client.start(branch: "NS-1") { _ in }
    try await Task.sleep(for: .milliseconds(200))
    await #expect(throws: NsFailure(message: "o ns rpc não respondeu a tempo")) { try await client.status() }
    try await started
}

@Test func stopCarriesTheNsError() async throws {
    let (client, folder) = try fakeNs(#"""
        read -r line
        echo '{"type":"error","id":"1","error":{"category":"nao-encontrado","message":"Branch \u0027x\u0027 não encontrada"}}'
        cat >/dev/null
        """#)
    defer { try? FileManager.default.removeItem(at: folder) }

    await #expect(throws: NsFailure(message: "Branch 'x' não encontrada")) {
        try await client.stop(branch: "x") { _ in }
    }
}

@Test func aServiceActionNamesTheService() async throws {
    let (client, folder) = try fakeNs(#"""
        read -r line
        printf '%s\n' "$line" > "$0.request"
        echo '{"type":"result","id":"1","result":{"branch":"NS-1"}}'
        cat >/dev/null
        """#)
    defer { try? FileManager.default.removeItem(at: folder) }

    try await client.stop(branch: "NS-1", service: "backend") { _ in }

    let request = try String(contentsOf: folder.appending(path: "ns.request"), encoding: .utf8)
    #expect(request.contains(#""op":"stop""#))
    #expect(request.contains(#""service":"backend""#))
}

@Test func withAnOverrideOnlyThatPathIsTried() async throws {
    let client = NsClient.locating(override: "/nonexistent/ns")
    await #expect(throws: NsFailure(message: "ns não encontrado no PATH")) { try await client.status() }
}

@Test func newAsksTheQuestionAndSendsTheAnswerBack() async throws {
    let (client, folder) = try fakeNs(#"""
        read -r line
        printf '%s\n' "$line" > "$0.request"
        echo '{"type":"event","id":"1","event":{"step":"new:validate","label":"Validando repositórios..."}}'
        printf '%s' '{"type":"ask","id":"1","ask":"a1",'
        echo '"question":{"id":"q","message":"Instalar dependências agora?","default":true,"whenUnavailable":"default"}}'
        read -r answer
        printf '%s\n' "$answer" > "$0.answer"
        printf '%s' '{"type":"result","id":"1","result":{"branch":"NS-1","paths":{"root":"/w/NS-1"},'
        echo '"missingRepos":[{"repo":"parents","category":"nao-encontrado","message":"sem main"}]}}'
        cat >/dev/null
        """#)
    defer { try? FileManager.default.removeItem(at: folder) }

    let steps = Recorder()
    let questions = Recorder()
    let created = try await client.new(branch: "NS-1", repos: ["manager", "parents"],
                                       steps: { steps.append($0.step) },
                                       ask: { questions.append($0.message); return false })

    #expect(created == NsClient.Created(paths: .init(root: "/w/NS-1"),
                                        missingRepos: [.init(repo: "parents", message: "sem main")]))
    #expect(steps.all == ["new:validate"])
    #expect(questions.all == ["Instalar dependências agora?"])
    let request = try String(contentsOf: folder.appending(path: "ns.request"), encoding: .utf8)
    #expect(request.contains(#""op":"new""#))
    #expect(request.contains(#""repos":["manager","parents"]"#))
    #expect(request.contains(#""installMissingDeps":"ask""#))
    let answer = try String(contentsOf: folder.appending(path: "ns.answer"), encoding: .utf8)
    #expect(answer.contains(#""type":"answer""#))
    #expect(answer.contains(#""ask":"a1""#))
    #expect(answer.contains(#""id":"1""#))
    #expect(answer.contains(#""value":false"#))
}

@Test func aQuestionWithoutSomeoneToAnswerTakesItsDefault() async throws {
    let (client, folder) = try fakeNs(#"""
        read -r line
        echo '{"type":"ask","id":"1","ask":"a1","question":{"id":"q","message":"?","default":true,"whenUnavailable":"default"}}'
        read -r answer
        printf '%s\n' "$answer" > "$0.answer"
        echo '{"type":"result","id":"1","result":{"branch":"NS-1"}}'
        cat >/dev/null
        """#)
    defer { try? FileManager.default.removeItem(at: folder) }

    try await client.addRepo(branch: "NS-1", repo: "parents") { _ in }

    let answer = try String(contentsOf: folder.appending(path: "ns.answer"), encoding: .utf8)
    #expect(answer.contains(#""value":true"#))
}

@Test func anErrorKeepsTheHintOfTheNs() async throws {
    let (client, folder) = try fakeNs(#"""
        read -r line
        printf '%s' '{"type":"error","id":"1","error":{"category":"ferramenta-externa","message":"docker parado",'
        echo '"hint":"A branch foi criada. Para preparar de novo: ns prepare NS-1"}}'
        cat >/dev/null
        """#)
    defer { try? FileManager.default.removeItem(at: folder) }

    await #expect(throws: NsFailure(message: "docker parado",
                                    hint: "A branch foi criada. Para preparar de novo: ns prepare NS-1")) {
        try await client.prepare(branch: "NS-1", steps: { _ in }, ask: { _ in true })
    }
}

@Test func aQuestionWaitingForTheUserDoesNotExpireTheRequest() async throws {
    let (client, folder) = try fakeNs(#"""
        read -r line
        echo '{"type":"ask","id":"1","ask":"a1","question":{"id":"q","message":"?","default":true,"whenUnavailable":"default"}}'
        read -r answer
        echo '{"type":"result","id":"1","result":{"branch":"NS-1"}}'
        cat >/dev/null
        """#)
    defer { try? FileManager.default.removeItem(at: folder) }

    try await client.prepare(branch: "NS-1", steps: { _ in }, ask: { _ in
        try? await Task.sleep(for: .seconds(3))
        return true
    })
}
