import AppKit
import Carbon.HIToolbox
import SwiftUI

enum FloatingPlacement: Equatable {
    case beside(Edge)
    case at(UnitPoint)
}

enum FloatingLayout {
    static func frame(size: CGSize, anchor: CGRect, placement: FloatingPlacement, screen: CGRect) -> CGRect {
        let gap = Theme.space(.s4)
        var origin: CGPoint
        switch placement {
        case .at(let unit):
            let point = CGPoint(x: anchor.minX + unit.x * anchor.width, y: anchor.maxY - unit.y * anchor.height)
            origin = CGPoint(x: point.x, y: point.y - size.height)
            if origin.y < screen.minY { origin.y = point.y }
            if origin.x + size.width > screen.maxX { origin.x = point.x - size.width }
        case .beside(let edge):
            let centered = CGPoint(x: anchor.midX - size.width / 2, y: anchor.midY - size.height / 2)
            let above = anchor.maxY + gap
            let below = anchor.minY - gap - size.height
            let before = anchor.minX - gap - size.width
            let after = anchor.maxX + gap
            switch edge {
            case .top:
                origin = CGPoint(x: centered.x, y: above + size.height > screen.maxY ? below : above)
            case .bottom:
                origin = CGPoint(x: centered.x, y: below < screen.minY ? above : below)
            case .leading:
                origin = CGPoint(x: before < screen.minX ? after : before, y: centered.y)
            case .trailing:
                origin = CGPoint(x: after + size.width > screen.maxX ? before : after, y: centered.y)
            }
        }
        origin.x = min(max(origin.x, screen.minX), max(screen.minX, screen.maxX - size.width))
        origin.y = min(max(origin.y, screen.minY), max(screen.minY, screen.maxY - size.height))
        return CGRect(origin: origin, size: size)
    }
}

extension View {
    func floating(isPresented: Binding<Bool>, edge: Edge = .top,
                  @ViewBuilder content: @escaping () -> some View) -> some View {
        background(FloatingAnchor(isPresented: isPresented, placement: .beside(edge), content: content))
    }

    func floating(isPresented: Binding<Bool>, at point: UnitPoint,
                  @ViewBuilder content: @escaping () -> some View) -> some View {
        background(FloatingAnchor(isPresented: isPresented, placement: .at(point), content: content))
    }
}

struct FloatingFrame<Content: View>: View {
    static var margin: CGFloat { Theme.space(.s16) }

    @ViewBuilder var content: Content

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radius(.r10), style: .continuous)
        content
            .background(Theme.raised)
            .clipShape(shape)
            .overlay(shape.strokeBorder(Theme.borderControl, lineWidth: Theme.line(.hairline)))
            .elevation(.floating)
            .padding(Self.margin)
    }
}

private struct FloatingAnchor<Content: View>: NSViewRepresentable {
    @Binding var isPresented: Bool
    let placement: FloatingPlacement
    let content: () -> Content

    func makeNSView(context: Context) -> FloatingAnchorView { FloatingAnchorView() }

    func updateNSView(_ view: FloatingAnchorView, context: Context) {
        let binding = $isPresented
        let root = AnyView(FloatingFrame { content() }.environment(\.self, context.environment))
        view.update(isPresented: isPresented, placement: placement, root: root) {
            binding.wrappedValue = false
        }
    }

    static func dismantleNSView(_ view: FloatingAnchorView, coordinator: ()) {
        view.close()
    }
}

final class FloatingAnchorView: NSView {
    private var panel: FloatingPanel?
    private var host: FloatingHost?
    private var placement = FloatingPlacement.beside(.top)
    private var dismiss: () -> Void = {}
    private var monitor: Any?
    private var observers: [NSObjectProtocol] = []

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil, panel != nil {
            close()
            let dismiss = dismiss
            DispatchQueue.main.async { dismiss() }
        }
    }

    func update(isPresented: Bool, placement: FloatingPlacement, root: AnyView, dismiss: @escaping () -> Void) {
        self.dismiss = dismiss
        guard isPresented else {
            close()
            return
        }
        let moved = self.placement != placement
        self.placement = placement
        if let host {
            host.rootView = root
            if moved { place() }
        } else {
            open(root)
        }
    }

    private func open(_ root: AnyView) {
        guard let window else { return }
        let host = FloatingHost(rootView: root)
        let panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: host.fittingSize))
        panel.contentView = host
        panel.cancel = { [weak self] in self?.dismiss() }
        host.resized = { [weak self] in self?.place() }
        self.host = host
        self.panel = panel
        place()
        window.addChildWindow(panel, ordered: .above)
        panel.makeKeyAndOrderFront(nil)
        watch(window)
    }

    func close() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        guard let panel else { return }
        let wasKey = panel.isKeyWindow
        panel.parent?.removeChildWindow(panel)
        panel.orderOut(nil)
        self.panel = nil
        host = nil
        if wasKey { window?.makeKey() }
    }

    private func place() {
        guard let window, let panel, let host else { return }
        let margin = FloatingFrame<EmptyView>.margin
        let anchor = window.convertToScreen(convert(bounds, to: nil))
        let screen = (window.screen ?? NSScreen.main)?.visibleFrame ?? anchor
        let fitting = host.fittingSize
        let outer = CGSize(width: fitting.width.rounded(.up), height: fitting.height.rounded(.up))
        let inner = CGSize(width: max(outer.width - 2 * margin, 0), height: max(outer.height - 2 * margin, 0))
        let frame = FloatingLayout.frame(size: inner, anchor: anchor, placement: placement, screen: screen)
        panel.setFrame(frame.insetBy(dx: -margin, dy: -margin), display: true)
    }

    private func watch(_ window: NSWindow) {
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) {
            [weak self] event in
            guard let self, let panel else { return event }
            var clicked = event.window
            while let current = clicked {
                if current === panel { return event }
                clicked = current.parent
            }
            let onAnchor = event.window === window
                && bounds.contains(convert(event.locationInWindow, from: nil))
            dismiss()
            if case .beside = placement, onAnchor, event.type == .leftMouseDown { return nil }
            return event
        }
        let center = NotificationCenter.default
        for (name, object) in [(NSApplication.didResignActiveNotification, nil as AnyObject?),
                               (NSWindow.willCloseNotification, window)] {
            observers.append(center.addObserver(forName: name, object: object, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.dismiss() }
            })
        }
    }
}

private final class FloatingHost: NSHostingView<AnyView> {
    var resized: () -> Void = {}
    private var resizing = false

    override func invalidateIntrinsicContentSize() {
        super.invalidateIntrinsicContentSize()
        guard !resizing else { return }
        resizing = true
        DispatchQueue.main.async { [weak self] in
            self?.resizing = false
            self?.resized()
        }
    }
}

private final class FloatingPanel: NSPanel {
    var cancel: () -> Void = {}

    init(contentRect: NSRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        makeTransient()
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) { cancel() }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) { cancel() } else { super.keyDown(with: event) }
    }
}

extension NSPanel {
    func makeTransient() {
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        collectionBehavior = [.transient, .ignoresCycle]
    }

    static func hoverPanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: true)
        panel.makeTransient()
        panel.ignoresMouseEvents = true
        return panel
    }
}

extension NSHostingController {
    static func fittingSize(of view: Content, maxWidth: CGFloat) -> CGSize {
        let size = NSHostingController(rootView: view).sizeThatFits(in: NSSize(width: maxWidth, height: 10_000))
        return CGSize(width: size.width.rounded(.up), height: size.height.rounded(.up))
    }
}
