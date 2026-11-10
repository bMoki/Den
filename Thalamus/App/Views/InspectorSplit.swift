import SwiftUI

struct InspectorSplit<Main: View, Inspector: View>: View {
    let isShown: Bool
    @ViewBuilder var main: () -> Main
    @ViewBuilder var inspector: () -> Inspector

    @AppStorage(PreferenceKey.named("inspectorWidth")) private var inspectorWidth: Double = 480

    private static var minimumMainWidth: CGFloat { 420 }
    private static var minimumInspectorWidth: Double { 320 }

    var body: some View {
        GeometryReader { geometry in
            let room = Double(geometry.size.width - Self.minimumMainWidth)
            let docked = room >= Self.minimumInspectorWidth
            HStack(spacing: 0) {
                main()

                if isShown, docked {
                    ResizeHandle(width: $inspectorWidth,
                                 range: Self.minimumInspectorWidth...room,
                                 growsTowardTrailing: false)
                    inspector()
                        .frame(width: min(max(inspectorWidth, Self.minimumInspectorWidth), room))
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .overlay(alignment: .trailing) {
                if isShown, !docked {
                    inspector()
                        .frame(width: min(max(inspectorWidth, Self.minimumInspectorWidth),
                                          Double(geometry.size.width) - 56))
                        .overlay(alignment: .leading) {
                            Rectangle().fill(Theme.borderStrong).frame(width: 1)
                        }
                        .shadow(color: .black.opacity(0.5), radius: 28, x: -8)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}
