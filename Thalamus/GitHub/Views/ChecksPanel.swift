import SwiftUI
import AppKit

struct ChecksRing: View {
    let summary: ChecksSummary

    @State private var turning = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.borderControl, lineWidth: Theme.line(.ring))
            Circle()
                .trim(from: 0, to: arc)
                .stroke(summary.color, style: StrokeStyle(lineWidth: Theme.line(.ring), lineCap: .round))
                .rotationEffect(.degrees(isRunning && turning ? 270 : -90))
                .animation(isRunning ? .linear(duration: 1.1).repeatForever(autoreverses: false)
                                     : .easeInOut(duration: 0.4), value: turning)
        }
        .animation(.easeInOut(duration: 0.4), value: arc)
        .onAppear { turning = true }
    }

    private var isRunning: Bool {
        if case .running = summary { return true }
        return false
    }

    private var arc: Double {
        switch summary {
        case .absent: 0
        case .running: 0.3
        case .passing: 1
        case .failing(let passed, let total): max(Double(passed) / Double(max(total, 1)), 0.04)
        }
    }
}

extension ChecksSummary {
    var color: Color {
        switch self {
        case .absent: Theme.textTertiary
        case .running: Theme.modified
        case .passing: Theme.added
        case .failing: Theme.removed
        }
    }

    var count: String {
        switch self {
        case .absent: ""
        case .running(let passed, let total), .failing(let passed, let total): "\(passed)/\(total)"
        case .passing(let total): "\(total)/\(total)"
        }
    }
}

extension CheckRun.State {
    var color: Color {
        switch self {
        case .failed: Theme.removed
        case .running: Theme.modified
        case .queued: Theme.borderControl
        case .passed: Theme.added
        case .skipped: Theme.textFaint
        }
    }
}

struct ChecksPanel: View {
    let pullRequest: PullRequest
    let checkedAt: Date?
    var refresh: () -> Void

    private static let maxListHeight: CGFloat = 320

    var body: some View {
        let checks = PullRequestStatus.ordered(pullRequest.checks)
        VStack(alignment: .leading, spacing: Theme.space(.s12)) {
            HStack(alignment: .firstTextBaseline) {
                Text("Checks")
                    .font(Theme.font(.body, weight: .semibold))
                Spacer()
                Text(PullRequestStatus.headline(pullRequest))
                    .font(Theme.font(.captionPlus, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
            }
            HStack(spacing: Theme.space(.s2)) {
                ForEach(Array(checks.enumerated()), id: \.offset) { _, check in
                    Rectangle().fill(check.state.color).frame(maxWidth: .infinity)
                }
            }
            .frame(height: Theme.size(.s8))
            .background(Theme.borderStrong)
            .clipShape(Capsule())
            FittedScroll(maxHeight: Self.maxListHeight) {
                VStack(alignment: .leading, spacing: Theme.space(.s2)) {
                    ForEach(Array(checks.enumerated()), id: \.offset) { _, check in
                        CheckRow(check: check)
                    }
                }
            }
            HStack {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(PullRequestStatus.updatedLabel(since: checkedAt, now: context.date))
                }
                .font(Theme.font(.caption))
                .foregroundStyle(Theme.textTertiary)
                Spacer()
                Button(action: refresh) {
                    Theme.image(.restart)
                        .font(Theme.font(.caption, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                        .iconLabel(size: .s24)
                }
                .buttonStyle(.thalamusGhost(radius: .r6))
                .tip("Atualizar agora")
                .accessibilityLabel("Atualizar")
            }
        }
        .padding(Theme.space(.s16))
        .frame(width: 340)
        .foregroundStyle(Theme.text)
        .background(Theme.raised)
    }
}

private struct CheckRow: View {
    let check: CheckRun

    @State private var hovering = false

    var body: some View {
        Button {
            if let url = check.url { NSWorkspace.shared.open(url) }
        } label: {
            HStack(spacing: Theme.space(.s8)) {
                swatch
                Text(check.name)
                    .foregroundStyle(check.state == .skipped ? Theme.textTertiary : Theme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: Theme.space(.s8))
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(PullRequestStatus.detail(of: check, at: context.date))
                }
                .font(Theme.font(.captionPlus, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
                Theme.image(.openInBrowser)
                    .font(Theme.font(.mini, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                    .opacity(check.url == nil ? 0 : 1)
            }
            .font(Theme.font(.smallPlus))
            .padding(.horizontal, Theme.space(.s6))
            .frame(height: Theme.size(.s26))
            .hoverFill(hovering && check.url != nil, radius: .r6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .disabled(check.url == nil)
    }

    @ViewBuilder
    private var swatch: some View {
        if check.state == .running {
            SpinningRing(color: check.state.color, size: .s10)
        } else {
            Swatch(color: check.state == .queued ? nil : check.state.color)
        }
    }
}
