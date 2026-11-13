import SwiftUI
import AppKit

struct PullRequestBar: View {
    let repo: BranchRepo
    let pullRequest: PullRequest
    let checkedAt: Date?
    var refresh: () -> Void
    var dismiss: () -> Void

    @State private var showingChecks = false
    @State private var hoveringChecks = false
    @State private var pulse = false

    private var tone: PullRequestTone { PullRequestStatus.tone(pullRequest) }

    var body: some View {
        HStack(spacing: Theme.space(.s10)) {
            Button { NSWorkspace.shared.open(pullRequest.url) } label: {
                HStack(spacing: Theme.space(.s10)) {
                    HStack(spacing: Theme.space(.s6)) {
                        Theme.image(tone.symbol, size: .small, weight: .semibold)
                            .foregroundStyle(tone.color)
                        Text(PullRequestStatus.number(pullRequest))
                            .font(Theme.font(.smallPlus, weight: .semibold))
                            .monospacedDigit()
                    }
                    Text(repo.name)
                        .font(Theme.font(.smallPlus))
                        .foregroundStyle(Theme.textTertiary)
                        .lineLimit(1)
                        .fixedSize()
                    Text(pullRequest.title)
                        .font(Theme.font(.smallPlus))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .tip("Abrir no GitHub · \(repo.branch)")
            trailing
            BarDismissButton(action: dismiss)
                .tip("Dispensar até o PR mudar")
        }
        .barSurface(fill: fill, stroke: stroke)
        .scaleEffect(pulse ? 1.015 : 1)
        .animation(.easeInOut(duration: 0.25), value: tone)
        .onChange(of: tone) { _, new in
            guard new == .merged else { return }
            withAnimation(.spring(response: 0.25, dampingFraction: 0.45)) { pulse = true }
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(250))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { pulse = false }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pull-request-bar")
    }

    @ViewBuilder
    private var trailing: some View {
        if pullRequest.state == .open, !pullRequest.isDraft {
            reviewPill
            diffPill
            if PullRequestStatus.checks(pullRequest) != .absent { checksChip }
        } else {
            diffPill
            Text(PullRequestStatus.label(pullRequest))
                .font(Theme.font(.captionPlus, weight: .medium))
                .foregroundStyle(tone.color)
                .padding(.horizontal, Theme.space(.s4))
                .fixedSize()
        }
    }

    @ViewBuilder
    private var reviewPill: some View {
        if pullRequest.mergeable == .conflicting {
            pill("Conflito com \(pullRequest.base.isEmpty ? "a base" : pullRequest.base)",
                 symbol: .warning, color: Theme.alertText, fill: Theme.alertFill)
        } else if pullRequest.review == .changesRequested {
            pill("Mudanças pedidas", symbol: .changesRequested,
                 color: Theme.alertText, fill: Theme.alertFill)
        } else if pullRequest.review == .approved {
            pill("Aprovado", symbol: .done, color: Theme.added, fill: Theme.addedFill)
        }
    }

    private func pill(_ text: String, symbol: Icon, color: Color, fill: Color) -> some View {
        HStack(spacing: Theme.space(.s5)) {
            Theme.image(symbol, size: .mini, weight: .bold)
            Text(text)
        }
        .font(Theme.font(.captionPlus, weight: .medium))
        .foregroundStyle(color)
        .padding(.horizontal, Theme.space(.s8))
        .frame(height: Theme.size(.s24))
        .background(fill, in: RoundedRectangle(cornerRadius: Theme.radius(.r7), style: .continuous))
        .fixedSize()
    }

    private var diffPill: some View {
        HStack(spacing: Theme.space(.s5)) {
            Text("+\(pullRequest.additions)").foregroundStyle(Theme.added)
            Text("−\(pullRequest.deletions)").foregroundStyle(Theme.removed)
        }
        .font(Theme.font(.captionPlus, design: .monospaced))
        .padding(.horizontal, Theme.space(.s8))
        .frame(height: Theme.size(.s24))
        .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.radius(.r7), style: .continuous))
        .fixedSize()
    }

    private var checksChip: some View {
        let summary = PullRequestStatus.checks(pullRequest)
        return Button { showingChecks.toggle() } label: {
            HStack(spacing: Theme.space(.s7)) {
                ChecksRing(summary: summary)
                    .frame(width: Theme.size(.s16), height: Theme.size(.s16))
                Text(summary.count)
                    .font(Theme.font(.small))
                    .monospacedDigit()
                    .foregroundStyle(summary == .passing(total: passingTotal) ? Theme.textTertiary
                                                                              : summary.color)
                    .lineLimit(1)
                    .fixedSize()
            }
            .chipLabel(horizontalPadding: .s8)
            .hoverFill(hoveringChecks, selected: showingChecks)
        }
        .buttonStyle(.plain)
        .onHover { hoveringChecks = $0 }
        .tip("Checks: \(PullRequestStatus.headline(pullRequest)) · clique para ver cada um")
        .accessibilityLabel("Checks")
        .accessibilityValue(PullRequestStatus.headline(pullRequest))
        .floating(isPresented: $showingChecks, edge: .top) {
            ChecksPanel(pullRequest: pullRequest, checkedAt: checkedAt, refresh: refresh)
        }
    }

    private var passingTotal: Int {
        if case .passing(let total) = PullRequestStatus.checks(pullRequest) { return total }
        return -1
    }

    private var fill: Color {
        switch tone {
        case .failure: Theme.removedFill
        case .merged: Theme.accentFill
        case .draft, .closed: Theme.card
        case .open, .attention: Theme.raised
        }
    }

    private var stroke: Color {
        switch tone {
        case .failure: Theme.removed.opacity(0.45)
        case .merged: Theme.accent.opacity(0.45)
        case .draft, .closed: Theme.borderCard
        case .open, .attention: Theme.borderControl
        }
    }
}

extension View {
    func barSurface(fill: Color, stroke: Color) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radius(.r12), style: .continuous)
        return padding(.leading, Theme.space(.s12))
            .padding(.trailing, Theme.space(.s6))
            .frame(height: Theme.size(.s36))
            .foregroundStyle(Theme.text)
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(stroke, lineWidth: Theme.line(.thin)).allowsHitTesting(false))
    }

    func barButtonLabel() -> some View {
        font(Theme.font(.small))
            .padding(.horizontal, Theme.space(.s10))
            .frame(height: Theme.size(.s26))
    }
}
