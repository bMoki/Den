import AppKit
import SwiftUI

struct BranchPullRequestRows: View {
    let repos: [BranchRepo]

    @Environment(PullRequestMonitor.self) private var monitor

    var body: some View {
        ForEach(Array(repos.enumerated()), id: \.element.id) { index, repo in
            row(repo, pullRequest: monitor.pullRequest(for: repo))
                .overlay(alignment: .top) {
                    if index > 0 { Rectangle().fill(Theme.border).frame(height: 1) }
                }
        }
    }

    @ViewBuilder
    private func row(_ repo: BranchRepo, pullRequest: PullRequest?) -> some View {
        let content = HStack(spacing: 8) {
            Text(repo.name)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 104, alignment: .leading)
            if let pullRequest {
                Text("\(PullRequestStatus.number(pullRequest)) \(pullRequest.title)")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                pill(pullRequest)
            } else {
                Text("sem PR")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.textFaint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .contentShape(Rectangle())
        if let pullRequest {
            Button { NSWorkspace.shared.open(pullRequest.url) } label: { content }
                .buttonStyle(.plain)
                .help("Abrir no GitHub")
                .accessibilityLabel("\(repo.name): PR \(PullRequestStatus.number(pullRequest)), \(PullRequestStatus.label(pullRequest))")
        } else {
            content
                .accessibilityElement(children: .combine)
        }
    }

    private func pill(_ pullRequest: PullRequest) -> some View {
        let tone = PullRequestStatus.tone(pullRequest)
        return Text(PullRequestStatus.label(pullRequest))
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(tone.color)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 7)
            .frame(height: 19)
            .background(tone.fill, in: Capsule())
    }
}
