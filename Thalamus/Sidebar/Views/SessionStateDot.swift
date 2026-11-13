import SwiftUI

struct SessionStateMark: View {
    let state: SessionState
    var showsWord = true

    var body: some View {
        switch Theme.style.sessionStates {
        case .animatedDot: SessionStateDot(state: state)
        case .glyphWord: SessionStateGlyph(state: state, showsWord: showsWord)
        }
    }
}

private struct SessionStateGlyph: View {
    private static let blinkPeriod = 1.2

    let state: SessionState
    let showsWord: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: Theme.space(.s8)) {
            Group {
                if reduceMotion || !state.moves {
                    glyph(frame: 0)
                } else {
                    TimelineView(.animation(minimumInterval: 0.1)) { context in
                        glyph(frame: Self.frame(at: context.date, state: state))
                    }
                }
            }
            if showsWord {
                Text(state.word).foregroundStyle(state.color)
            }
        }
        .font(Theme.font(.body))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.name)
    }

    @ViewBuilder
    private func glyph(frame: Int) -> some View {
        switch state {
        case .awaitingDecision:
            Text("!")
                .foregroundStyle(frame == 1 ? Theme.canvas : state.color)
                .background(frame == 1 ? state.color : .clear)
        case .outOfTokens: Text("×").foregroundStyle(state.color)
        case .newReply: Text("●").foregroundStyle(state.color)
        case .thinking: Text(GlyphSpinner.frames[frame]).foregroundStyle(state.color)
        }
    }

    private static func frame(at date: Date, state: SessionState) -> Int {
        let time = date.timeIntervalSinceReferenceDate
        switch state {
        case .thinking: return GlyphSpinner.frame(at: date)
        default: return Int(time / (blinkPeriod / 2)) % 2
        }
    }
}

private extension SessionState {
    var moves: Bool { self == .thinking || self == .awaitingDecision }

    var word: String {
        switch self {
        case .awaitingDecision: "aguardando"
        case .outOfTokens: "sem tokens"
        case .newReply: "nova"
        case .thinking: "pensando"
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
        tip(label)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
    }
}
