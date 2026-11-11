import AppKit
import SwiftUI

extension View {
    func tip(_ text: String, shortcut: String? = nil) -> some View {
        modifier(TipModifier(text: text, shortcut: shortcut))
    }
}

private struct TipModifier: ViewModifier {
    let text: String
    let shortcut: String?

    @State private var id = UUID()

    func body(content: Content) -> some View {
        content
            .onHover { inside in
                if inside, !text.isEmpty {
                    TipCenter.shared.hover(id, TipLabel(text: text, shortcut: shortcut))
                } else {
                    TipCenter.shared.leave(id)
                }
            }
            .onDisappear { TipCenter.shared.leave(id) }
            .accessibilityHint(text)
    }
}

struct TipLabel: View {
    static let maxWidth: CGFloat = 320
    static var margin: CGFloat { Theme.space(.s12) }

    let text: String
    var shortcut: String?
    var width: CGFloat?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radius(.r5), style: .continuous)
        ViewThatFits(in: .horizontal) {
            content(wraps: false)
            content(wraps: true)
        }
        .font(Theme.font(.caption))
        .frame(width: width.map { $0 - 2 * Theme.space(.s7) }, alignment: .leading)
        .padding(.horizontal, Theme.space(.s7))
        .padding(.vertical, Theme.space(.s4))
        .background(Theme.tip, in: shape)
        .overlay(shape.strokeBorder(Theme.borderControl, lineWidth: Theme.line(.hairline)))
        .elevation(.tip)
        .padding(Self.margin)
    }

    private func content(wraps: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.space(.s8)) {
            Text(text)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: !wraps, vertical: true)
            if let shortcut {
                Text(shortcut)
                    .font(Theme.font(.caption, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize()
            }
        }
    }
}

@MainActor
final class TipCenter {
    static let shared = TipCenter()

    static let delay = Duration.milliseconds(900)
    static let warmDelay = Duration.milliseconds(80)
    private static let warmFor: TimeInterval = 0.6

    private var panel: NSPanel?
    private var owner: UUID?
    private var pending: Task<Void, Never>?
    private var hiddenAt = Date.distantPast
    private var monitor: Any?

    private var observers: [NSObjectProtocol] = []

    private var isWarm: Bool {
        panel?.isVisible == true || Date().timeIntervalSince(hiddenAt) < Self.warmFor
    }

    func hover(_ id: UUID, _ label: TipLabel) {
        pending?.cancel()
        let wait = isWarm ? Self.warmDelay : Self.delay
        hide()
        owner = id
        watch()
        pending = Task { [weak self] in
            try? await Task.sleep(for: wait)
            guard !Task.isCancelled, let self, owner == id else { return }
            show(label)
        }
    }

    func leave(_ id: UUID) {
        guard owner == id else { return }
        dismiss()
    }

    private func dismiss() {
        owner = nil
        pending?.cancel()
        hide()
    }

    private func show(_ label: TipLabel) {
        let size = NSHostingController.fittingSize(of: label, maxWidth: TipLabel.maxWidth + 2 * TipLabel.margin)
        var label = label
        label.width = size.width - 2 * TipLabel.margin
        let host = NSHostingView(rootView: label)
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) }?.visibleFrame
            ?? CGRect(origin: mouse, size: size)
        let margin = TipLabel.margin
        let below = CGPoint(x: mouse.x - margin, y: mouse.y - Theme.size(.s20) - size.height + margin)
        let origin = CGPoint(x: min(max(below.x, screen.minX), screen.maxX - size.width),
                             y: below.y < screen.minY ? mouse.y + Theme.space(.s4) - margin : below.y)
        let panel = self.panel ?? makePanel()
        panel.contentView = host
        panel.setFrame(CGRect(origin: origin, size: size), display: true)
        panel.orderFront(nil)
    }

    private func watch() {
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]) { [weak self] event in
            self?.dismiss()
            return event
        }
        let center = NotificationCenter.default
        observers = [NSApplication.didResignActiveNotification, NSWindow.willCloseNotification].map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.dismiss() }
            }
        }
    }

    private func hide() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        guard let panel, panel.isVisible else { return }
        panel.orderOut(nil)
        hiddenAt = Date()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel.hoverPanel()
        panel.level = .popUpMenu
        self.panel = panel
        return panel
    }
}
