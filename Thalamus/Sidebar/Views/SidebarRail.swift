import SwiftUI
import AppKit

struct PaneTip: Equatable {
    let title: String
    var caption: String?
    let detail: String?
    let state: SessionState?
    let anchor: CGRect
    var lines: [Line] = []

    struct Line: Equatable {
        let color: Color?
        let text: String

        static func pullRequests(_ bars: [PullRequestMonitor.Bar]) -> [Line] {
            bars.map { bar in
                Line(color: PullRequestStatus.tone(bar.pullRequest).color,
                     text: "\(bar.repo.name) \(PullRequestStatus.number(bar.pullRequest)) · "
                         + PullRequestStatus.label(bar.pullRequest))
            }
        }
    }
}

struct PaneHoverCard: View {
    static let maxWidth: CGFloat = 240
    static var margin: CGFloat { Theme.space(.s12) }

    let tip: PaneTip

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space(.s3)) {
            Text(tip.title)
                .font(Theme.font(.small, weight: .semibold))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            if let caption = tip.caption {
                Text(caption)
                    .font(Theme.font(.labelPlus, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
            if let detail = tip.detail {
                Text(detail)
                    .font(Theme.font(.labelPlus))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            ForEach(Array(tip.lines.enumerated()), id: \.offset) { _, line in
                HStack(spacing: Theme.space(.s5)) {
                    if let color = line.color {
                        Circle().fill(color).frame(width: Theme.size(.s6), height: Theme.size(.s6))
                    }
                    Text(line.text)
                        .font(Theme.font(.labelPlus))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            if let state = tip.state {
                HStack(spacing: Theme.space(.s5)) {
                    Circle()
                        .fill(state.color)
                        .frame(width: Theme.size(.s6), height: Theme.size(.s6))
                    Text(state.name)
                        .font(Theme.font(.labelPlus))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, Theme.space(.s1))
            }
        }
        .padding(.horizontal, Theme.space(.s12))
        .padding(.vertical, Theme.space(.s10))
        .frame(minWidth: 120, alignment: .leading)
        .foregroundStyle(Theme.text)
        .background(Theme.tip, in: RoundedRectangle(cornerRadius: Theme.radius(.r10), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius(.r10), style: .continuous)
            .strokeBorder(Theme.borderControl, lineWidth: Theme.line(.thin)))
        .elevation(.tip)
        .padding(Self.margin)
    }
}

@MainActor
final class HoverTipPanel {
    static let shared = HoverTipPanel()

    private var panel: NSPanel?
    private(set) var isVisible = false

    func show(_ tip: PaneTip) {
        guard let window = NSApp.mainWindow ?? NSApp.keyWindow,
              let content = window.contentView else { return }

        let host = NSHostingView(rootView: PaneHoverCard(tip: tip))
        let size = Self.size(of: tip)

        let panel = self.panel ?? makePanel()
        panel.contentView = host

        let flippedY = content.bounds.height - tip.anchor.midY
        let inWindow = NSPoint(x: tip.anchor.maxX - 4, y: flippedY)
        var origin = window.convertPoint(toScreen: inWindow)
        origin.y -= size.height / 2
        if let screen = window.screen {
            origin.y = max(screen.visibleFrame.minY,
                           min(origin.y, screen.visibleFrame.maxY - size.height))
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.alphaValue = 0
        panel.orderFront(nil)
        NSAnimationContext.runAnimationGroup { animation in
            animation.duration = 0.12
            panel.animator().alphaValue = 1
        }
        isVisible = true
    }

    static func size(of tip: PaneTip) -> NSSize {
        NSHostingController.fittingSize(of: PaneHoverCard(tip: tip),
                                        maxWidth: PaneHoverCard.maxWidth + 2 * PaneHoverCard.margin)
    }

    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel.hoverPanel()
        panel.level = .floating
        self.panel = panel
        return panel
    }
}

struct HoverTipModifier: ViewModifier {
    let enabled: Bool
    let make: (CGRect) -> PaneTip
    let update: (PaneTip?) -> Void

    @State private var anchor: CGRect = .zero

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { anchor = $0 }
            .onHover { inside in
                guard enabled else { return }
                update(inside ? make(anchor) : nil)
            }
    }
}

extension View {
    func hoverTip(enabled: Bool = true,
                  _ make: @escaping (CGRect) -> PaneTip,
                  update: @escaping (PaneTip?) -> Void) -> some View {
        modifier(HoverTipModifier(enabled: enabled, make: make, update: update))
    }
}
