import SwiftUI

struct FittedScroll<Content: View>: View {
    var maxHeight: CGFloat
    var fadesHiddenEnd = false
    @ViewBuilder var content: () -> Content

    @State private var height: CGFloat = 0
    @State private var endIsHidden = false

    var body: some View {
        ScrollView {
            content()
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                    height = $0
                }
        }
        .scrollBounceBehavior(.basedOnSize)
        .onScrollGeometryChange(for: Bool.self) { geometry in
            fadesHiddenEnd && geometry.visibleRect.maxY < geometry.contentSize.height - 1
        } action: { _, hidden in
            endIsHidden = hidden
        }
        .mask {
            VStack(spacing: 0) {
                Rectangle()
                if endIsHidden {
                    // swiftlint:disable:next color_outside_palette
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: Self.fadeHeight)
                }
            }
        }
        .frame(height: min(max(height, 1), maxHeight))
    }

    private static var fadeHeight: CGFloat { 28 }
}
