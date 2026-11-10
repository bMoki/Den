import SwiftUI

private struct Pulsing: ViewModifier {
    let isOn: Bool

    @State private var dimmed = false

    func body(content: Content) -> some View {
        content
            .opacity(isOn && dimmed ? 0.35 : 1)
            .task(id: isOn) {
                dimmed = false
                guard isOn else { return }
                withAnimation(.easeInOut(duration: 0.55).repeatForever()) { dimmed = true }
            }
    }
}

extension View {
    func pulsing(_ isOn: Bool) -> some View {
        modifier(Pulsing(isOn: isOn))
    }
}
