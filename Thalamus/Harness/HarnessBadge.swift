import SwiftUI
import HarnessCore
import ClaudeHarness
import OpenCodeHarness

struct HarnessBadge: View {

    let harness: HarnessID?
    var size: Style.Size = .s15

    var body: some View {
        let side = Theme.size(size)
        Group {
            if let harness, let icon = Self.icon(for: harness) {
                Theme.image(icon)
                    .resizable()
                    .interpolation(.high)
            } else {

                Text(harness.map { Self.name(for: $0).prefix(1) } ?? "?")
                    .font(Theme.font(fitting: side, weight: .bold))
                    .foregroundStyle(Theme.onBadge)
                    .frame(width: side, height: side)
                    .background(.secondary)
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius(fitting: side), style: .continuous))
    }

    static func menuIcon(for harness: HarnessID, size: Style.Size = .s16) -> Image {
        guard let icon = icon(for: harness), let source = Theme.nsImage(icon) else {
            return Theme.image(.harnessDot)
        }
        let side = Theme.size(size)
        let radius = Theme.radius(fitting: side)
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).addClip()
            source.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            return true
        }
        return Image(nsImage: image)
    }

    nonisolated static func icon(for harness: HarnessID) -> Icon? {
        switch harness {
        case .claudeCode: .claudeCode
        case .openCode: .openCode
        default: nil
        }
    }

    nonisolated static func name(for harness: HarnessID) -> String {
        HarnessRegistry.standard.displayName(for: harness)
    }
}
