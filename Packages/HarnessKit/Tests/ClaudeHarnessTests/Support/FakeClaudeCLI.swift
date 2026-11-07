import Foundation
import HarnessCore
import HarnessTestSupport
@testable import ClaudeHarness

func fakeClaudeSession(running script: String) throws -> ClaudeSession {
    let executable = URL(fileURLWithPath: NSTemporaryDirectory())
        .appending(path: "fake-claude-\(UUID().uuidString)")
    try script.write(to: executable, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: 0o755],
                                          ofItemAtPath: executable.path)
    return ClaudeSession(
        installation: HarnessInstallation(executable: executable.path, version: "2.1.274"),
        workingDirectory: URL(fileURLWithPath: NSTemporaryDirectory()))
}

func askFakeClaude<T: Sendable>(running script: String,
                                _ question: @escaping @Sendable (ClaudeSession) async -> T) async throws -> T {
    let subject = try fakeClaudeSession(running: script)
    let updates = try await subject.start(.fresh)
    let drain = Task { for await _ in updates {} }
    defer { drain.cancel() }
    let answer = try await withTimeout(seconds: 5) { await question(subject) }
    await subject.stop()
    return answer
}
