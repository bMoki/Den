import AppKit
import CodeEditSourceEditor

final class EditorClipping: TextViewCoordinator {
    static let shared = EditorClipping()

    func prepareCoordinator(controller: TextViewController) {}

    func controllerDidAppear(controller: TextViewController) {
        controller.view.clipsToBounds = true
        controller.scrollView?.clipsToBounds = true
    }
}
