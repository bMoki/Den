import SwiftUI

extension View {
    func area(_ title: String, fill: Color, tint: Color = Theme.borderStrong, titleColor: Color = Theme.textTertiary,
              titleLeading: CGFloat = 0) -> some View {
        modifier(AreaBox(title: Text(title), fill: fill, tint: tint, titleColor: titleColor, titleLeading: titleLeading))
    }

    func titledCard(_ title: String?, border: Color = Theme.borderControl, accent: Color? = nil) -> some View {
        Group {
            if Theme.style.boxes == .lines, let title {
                area(title, fill: Theme.canvas, tint: accent ?? border, titleColor: accent ?? Theme.textTertiary)
            } else {
                card(border: border)
            }
        }
    }
}

private struct AreaBox: ViewModifier {
    let title: Text
    let fill: Color
    let tint: Color
    let titleColor: Color
    let titleLeading: CGFloat

    func body(content: Content) -> some View {
        switch Theme.style.boxes {
        case .surfaces:
            content
        case .lines:
            content
                .padding(.top, LineBox.titleRoom)
                .padding(Theme.line(.thin))
                .background(fill)
                .overlay {
                    LineBox(title: title, fill: fill, tint: tint, titleColor: titleColor, titleLeading: titleLeading)
                        .allowsHitTesting(false)
                }
                .padding(.top, LineBox.titleRoom + Theme.space(.s4))
                .padding(.horizontal, Theme.space(.s4))
                .padding(.bottom, Theme.space(.s4))
        }
    }
}

struct LineBox: View {
    static var titleRoom: CGFloat { Theme.space(.s8) }

    let title: Text
    let fill: Color
    let tint: Color
    let titleColor: Color
    var titleLeading: CGFloat = 0

    var body: some View {
        Rectangle()
            .strokeBorder(tint, lineWidth: Theme.line(.thin))
            .overlay(alignment: .topLeading) {
                title
                    .font(Theme.font(.body))
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                    .padding(.horizontal, Theme.space(.s4))
                    .background(fill)
                    .alignmentGuide(.top) { $0[VerticalAlignment.center] }
                    .padding(.leading, titleLeading + Theme.space(.s8))
            }
    }
}
