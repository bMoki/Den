import Testing
import Foundation
@testable import ClaudeHarness

private func cli(answering response: String) -> String {
    #"""
    #!/bin/sh
    while IFS= read -r l; do
      case "$l" in
        *'"subtype":"cancel_async_message"'*)
          id=$(printf '%s' "$l" | sed -n 's/.*"request_id":"\([^"]*\)".*/\1/p')
          printf '{"type":"control_response","response":{"subtype":"success","request_id":"%s","response":\#(response)}}\n' "$id"
          ;;
      esac
    done
    """#
}

@Test(arguments: [(#"{"cancelled":true}"#, true), (#"{"cancelled":false}"#, false), ("{}", false)])
func withdrawingAQueuedMessageReportsWhetherTheCLIDroppedIt(response: String, withdrawn: Bool) async throws {
    let answer = try await askFakeClaude(running: cli(answering: response)) { await $0.withdraw(UUID()) }

    #expect(answer == withdrawn)
}
