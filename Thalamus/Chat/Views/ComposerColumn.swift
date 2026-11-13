import SwiftUI

extension View {
    func composerColumn() -> some View {
        padding(.horizontal, Theme.space(.s32))
            .padding(.top, Theme.space(.s6))
            .padding(.bottom, Theme.space(.s20))
            .frame(maxWidth: 784)
            .frame(maxWidth: .infinity)
    }

    func aboveComposer(fade: CGFloat) -> some View {
        padding(.horizontal, Theme.space(.s32))
            .frame(maxWidth: 784)
            .frame(maxWidth: .infinity)
            .padding(.top, Theme.space(.s12))
            .padding(.bottom, Theme.space(.s4))
            .background {
                LinearGradient(colors: [Theme.canvas.opacity(0), Theme.canvas],
                               startPoint: .top, endPoint: .init(x: 0.5, y: fade))
            }
    }
}
