import Testing
import Foundation
@testable import Thalamus

private func output(_ text: String) -> Data { Data(text.utf8) }

nonisolated private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func bump() { lock.withLock { value += 1 } }
    var count: Int { lock.withLock { value } }
}

@Test func parseReadsOnlyWhatFollowsTheMarker() {
    let data = output("Welcome to fish\n__THALAMUS_ENV__\nPATH=/x:/y\u{0}HOME=/h\u{0}")
    #expect(ShellEnvironment.parse(data) == ["PATH": "/x:/y", "HOME": "/h"])
}

@Test func parseKeepsEverythingAfterTheFirstEquals() {
    let data = output("__THALAMUS_ENV__\nDATABASE_URL=postgres://u:p@h/db?a=b\u{0}")
    #expect(ShellEnvironment.parse(data)?["DATABASE_URL"] == "postgres://u:p@h/db?a=b")
}

@Test func parseDropsShellBookkeepingVariables() {
    let data = output("__THALAMUS_ENV__\nPATH=/x\u{0}PWD=/home\u{0}OLDPWD=/\u{0}SHLVL=2\u{0}_=/usr/bin/env\u{0}")
    #expect(ShellEnvironment.parse(data) == ["PATH": "/x"])
}

@Test func parseWithoutTheMarkerIsNil() {
    #expect(ShellEnvironment.parse(output("PATH=/x\u{0}")) == nil)
}

@Test func fallbackPrependsHomebrewPathsOnce() {
    let result = ShellEnvironment.fallback(from: ["PATH": "/usr/bin:/usr/local/bin", "PWD": "/"])
    #expect(result["PATH"] == "/opt/homebrew/bin:/usr/bin:/usr/local/bin")
    #expect(result["PWD"] == nil)
}

@Test func resolveUsesTheProbeOnceAndCaches() async {
    let calls = CallCounter()
    let environment = ShellEnvironment(shell: "/bin/zsh", base: [:]) { shell, arguments, _ in
        calls.bump()
        #expect(shell == "/bin/zsh")
        #expect(arguments == ["-l", "-i", "-c", "echo __THALAMUS_ENV__; /usr/bin/env -0"])
        return Data("__THALAMUS_ENV__\nPATH=/nvm/bin\u{0}".utf8)
    }
    let first = await environment.resolve()
    let second = await environment.resolve()
    #expect(first == ShellEnvironment.Resolved(variables: ["PATH": "/nvm/bin"], warning: nil))
    #expect(second == first)
    #expect(calls.count == 1)
}

@Test func aFailedProbeFallsBackWithAWarning() async {
    let environment = ShellEnvironment(shell: "/bin/zsh", base: ["PATH": "/usr/bin"]) { _, _, _ in nil }
    let resolved = await environment.resolve()
    #expect(resolved.warning == ShellEnvironment.fallbackWarning)
    #expect(resolved.variables["PATH"] == "/opt/homebrew/bin:/usr/local/bin:/usr/bin")
}

@Test func anOutputWithoutPathAlsoFallsBack() async {
    let environment = ShellEnvironment(shell: "/bin/zsh", base: [:]) { _, _, _ in
        Data("__THALAMUS_ENV__\nHOME=/h\u{0}".utf8)
    }
    #expect(await environment.resolve().warning == ShellEnvironment.fallbackWarning)
}

@Test func theLiveProbeReadsARealShell() async throws {
    let data = try #require(await ShellProbe.run(
        shell: "/bin/sh", arguments: ["-c", "echo __THALAMUS_ENV__; /usr/bin/env -0"],
        timeout: .seconds(10)))
    #expect(ShellEnvironment.parse(data)?["PATH"] != nil)
}

@Test func theLiveProbeGivesUpOnAHungShell() async {
    let data = await ShellProbe.run(shell: "/bin/sh", arguments: ["-c", "sleep 30"],
                                    timeout: .milliseconds(300))
    #expect(data == nil)
}
