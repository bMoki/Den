import SwiftUI

struct GlyphSpinner: View {
    static let codes: ClosedRange<UInt32> = 0xEE06...0xEE0B
    static let frames = codes.map(Style.character)
    static let period = 0.6

    let color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                Text(Self.frames[0])
            } else {
                TimelineView(.animation(minimumInterval: 0.1)) { context in
                    Text(Self.frames[Self.frame(at: context.date)])
                }
            }
        }
        .font(Theme.font(.body))
        .foregroundStyle(color)
    }

    static func frame(at date: Date) -> Int {
        Int(date.timeIntervalSinceReferenceDate / period * Double(frames.count)) % frames.count
    }
}
