import AppKit
import SwiftUI

struct PullRequestFollowing: ViewModifier {
    let branch: String?
    let busy: Bool

    @Environment(PullRequestMonitor.self) private var monitor

    func body(content: Content) -> some View {
        content
            .task(id: branch) {
                guard let branch else { return }
                monitor.appear(branch)
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(3600))
                }
                monitor.disappear(branch)
            }
            .onChange(of: busy) {
                if !busy, let branch { monitor.turnEnded(branch) }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: NSApplication.didBecomeActiveNotification)) { _ in
                Task { @MainActor in monitor.appBecameActive() }
            }
    }
}

extension View {
    func followsPullRequests(of branch: String?, busy: Bool) -> some View {
        modifier(PullRequestFollowing(branch: branch, busy: busy))
    }
}
