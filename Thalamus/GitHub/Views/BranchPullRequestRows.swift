import AppKit
import SwiftUI

struct BranchPullRequestRows: View {
    let repos: [BranchRepo]

    @Environment(PullRequestMonitor.self) private var monitor

    var body: some View {
        ForEach(Array(repos.enumerated()), id: \.element.id) { index, repo in
            Group {
                if let pullRequest = monitor.pullRequest(for: repo) {
                    PullRequestRow(repo: repo, pullRequest: pullRequest, isDismissed: monitor.isDismissed(repo)) {
                        monitor.toggleDismissal(of: repo)
                    }
                } else {
                    HStack(spacing: Theme.space(.s8)) {
                        RepoName(name: repo.name)
                        Text("sem PR")
                            .font(Theme.font(.smallPlus))
                            .foregroundStyle(Theme.textFaint)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, Theme.space(.s12))
                    .frame(height: Theme.size(.s38))
                    .accessibilityElement(children: .combine)
                }
            }
            .overlay(alignment: .top) {
                if index > 0 { Rectangle().fill(Theme.border).frame(height: Theme.line(.thin)) }
            }
        }
    }
}

private struct PullRequestRow: View {
    let repo: BranchRepo
    let pullRequest: PullRequest
    let isDismissed: Bool
    var toggleDismissal: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: Theme.space(.s4)) {
            Button { NSWorkspace.shared.open(pullRequest.url) } label: {
                HStack(spacing: Theme.space(.s8)) {
                    RepoName(name: repo.name)
                    Text("\(PullRequestStatus.number(pullRequest)) \(pullRequest.title)")
                        .font(Theme.font(.smallPlus))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    pill
                }
                .opacity(isDismissed ? 0.45 : 1)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Abrir no GitHub")
            .accessibilityLabel("\(repo.name): PR \(PullRequestStatus.number(pullRequest)), \(status)")
            Button(action: toggleDismissal) {
                Theme.image(isDismissed ? .show : .hide)
                    .font(Theme.font(.labelPlus, weight: .medium))
                    .foregroundStyle(isDismissed ? Theme.textMuted : Theme.textTertiary)
                    .iconLabel(size: .s24)
            }
            .buttonStyle(.thalamusGhost(radius: .r6))
            .opacity(hovering || isDismissed ? 1 : 0)
            .help(dismissalTitle)
            .accessibilityLabel("\(dismissalTitle): \(repo.name)")
        }
        .padding(.leading, Theme.space(.s12))
        .padding(.trailing, Theme.space(.s6))
        .frame(height: Theme.size(.s38))
        .onHover { hovering = $0 }
    }

    private var dismissalTitle: String {
        isDismissed ? "Mostrar de novo" : "Dispensar até o PR mudar"
    }

    private var status: String {
        let label = PullRequestStatus.label(pullRequest)
        return isDismissed ? "Dispensado · \(label)" : label
    }

    private var pill: some View {
        let tone = PullRequestStatus.tone(pullRequest)
        return Text(status)
            .font(Theme.font(.caption, weight: .medium))
            .foregroundStyle(tone.color)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, Theme.space(.s7))
            .frame(height: Theme.size(.s19))
            .background(tone.fill, in: Capsule())
    }
}

private struct RepoName: View {
    let name: String

    var body: some View {
        Text(name)
            .font(Theme.font(.small, design: .monospaced))
            .foregroundStyle(Theme.textSecondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(width: 104, alignment: .leading)
    }
}
