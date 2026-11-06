import Testing
import Foundation
@testable import ClaudeHarness

private func cli(answering cancelled: Bool) -> String {
    #"""
    #!/bin/sh
    while IFS= read -r l; do
      case "$l" in
        *'"subtype":"cancel_async_message"'*)
          id=$(printf '%s' "$l" | sed -n 's/.*"request_id":"\([^"]*\)".*/\1/p')
          printf '{"type":"control_response","response":{"subtype":"success","request_id":"%s","response":{"cancelled":\#(cancelled)}}}\n' "$id"
          ;;
      esac
    done
    """#
}

@Test(arguments: [true, false])
func withdrawingAQueuedMessageReportsWhetherTheCLIDroppedIt(cancelled: Bool) async throws {
    let withdrawn = try await askFakeClaude(running: cli(answering: cancelled)) { await $0.withdraw(UUID()) }

    #expect(withdrawn == cancelled)
}
