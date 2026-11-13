import SwiftUI

struct SpinningRing: View {
    let color: Color
    var size: Style.Size = .s10
    @State private var turning = false

    var body: some View {
        switch Theme.style.marks {
        case .graphic: ring
        case .characters: GlyphSpinner(color: color)
        }
    }

    private var ring: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(color, style: StrokeStyle(lineWidth: Theme.line(.spinner), lineCap: .round))
            .frame(width: Theme.size(size), height: Theme.size(size))
            .rotationEffect(.degrees(turning ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: turning)
            .onAppear { turning = true }
    }
}
