import SwiftUI

struct SessionStateMark: View {
    let state: SessionState

    var body: some View {
        switch Theme.style.sessionStates {
        case .animatedDot: SessionStateDot(state: state)
        }
    }
}

private struct SessionStateDot: View {
    private static let box: CGFloat = 8
    private static let diameter: CGFloat = 6

    private static let ripplePeriod = 1.8
    private static let rippleGrowth: CGFloat = 1.6
    private static let rippleOpacity = 0.8
    private static let orbitPeriod = 0.9
    private static let orbitArc: CGFloat = 0.4
    private static let orbitLineWidth: CGFloat = 1.4
    private static let orbitCore: CGFloat = 3
    private static let orbitCoreOpacity = 0.55

    let state: SessionState

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch reduceMotion ? nil : state {
            case .awaitingDecision: ripple
            case .thinking: orbit
            default: dot
            }
        }
        .frame(width: Self.box, height: Self.box)
    }

    private var dot: some View {
        Circle().fill(state.color).frame(width: Self.diameter, height: Self.diameter)
    }

    private var ripple: some View {
        TimelineView(.animation) { context in
            let eased = UnitCurve.easeOut.value(at: Self.progress(at: context.date, period: Self.ripplePeriod))
            dot.overlay(
                Circle()
                    .strokeBorder(state.color, lineWidth: Theme.line(.thin))
                    .scaleEffect(1 + Self.rippleGrowth * eased)
                    .opacity(Self.rippleOpacity * (1 - eased))
            )
        }
    }

    private var orbit: some View {
        TimelineView(.animation) { context in
            ZStack {
                Circle()
                    .fill(state.color.opacity(Self.orbitCoreOpacity))
                    .frame(width: Self.orbitCore, height: Self.orbitCore)
                Circle()
                    .trim(from: 0, to: Self.orbitArc)
                    .stroke(state.color, lineWidth: Self.orbitLineWidth)
                    .padding(Self.orbitLineWidth / 2)
                    .rotationEffect(.degrees(360 * Self.progress(at: context.date, period: Self.orbitPeriod)))
            }
        }
    }

    private static func progress(at date: Date, period: Double) -> Double {
        date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
    }
}

extension View {
    func describedAs(_ label: String) -> some View {
        help(label)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
    }
}
