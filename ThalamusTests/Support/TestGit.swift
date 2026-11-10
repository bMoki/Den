import Foundation
import HarnessCore

func git(_ arguments: [String], in directory: URL) async throws {
    _ = try await SystemCommandRunner().run("/usr/bin/git", [
        "-C", directory.path, "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null",
        "-c", "user.name=Thalamus Tests", "-c", "user.email=tests@thalamus.invalid",
    ] + arguments)
}
