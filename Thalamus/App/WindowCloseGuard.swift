import AppKit
import ObjectiveC
import SwiftUI

struct WindowCloseGuard: NSViewRepresentable {
    var shouldClose: () -> Bool

    func makeNSView(context: Context) -> GuardView {
        let view = GuardView()
        view.shouldClose = shouldClose
        return view
    }

    func updateNSView(_ view: GuardView, context: Context) {
        view.shouldClose = shouldClose
        view.install()
    }

    final class GuardView: NSView {
        var shouldClose: () -> Bool = { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            install()
        }

        func install() {
            guard let window, !(window.delegate is CloseAsking) else { return }
            CloseAsking.install(on: window) { [weak self] in self?.shouldClose() ?? true }
        }
    }
}

private final class CloseAsking: NSObject, NSWindowDelegate {
    private static var key: UInt8 = 0

    private weak var wrapped: (any NSWindowDelegate)?
    private let shouldClose: () -> Bool

    private init(wrapping wrapped: (any NSWindowDelegate)?, shouldClose: @escaping () -> Bool) {
        self.wrapped = wrapped
        self.shouldClose = shouldClose
    }

    static func install(on window: NSWindow, shouldClose: @escaping () -> Bool) {
        let asking = CloseAsking(wrapping: window.delegate, shouldClose: shouldClose)
        objc_setAssociatedObject(window, &key, asking, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        window.delegate = asking
    }

    override func responds(to selector: Selector!) -> Bool {
        super.responds(to: selector) || wrapped?.responds(to: selector) == true
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        wrapped
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard shouldClose() else { return false }
        return wrapped?.windowShouldClose?(sender) ?? true
    }
}
