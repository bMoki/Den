import SwiftUI

struct CompactionProgressCard: View {
    let since: Date

    @State private var phase: CGFloat = 0

    var body: some View {
        HStack(alignment: .top, spacing: Theme.space(.s11)) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.16))
                    .frame(width: Theme.size(.s30), height: Theme.size(.s30))
                Theme.image(.compact)
                    .font(Theme.font(.small, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }

            VStack(alignment: .leading, spacing: Theme.space(.s7)) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.space(.s8)) {
                    Text("Compactando a conversa")
                        .font(Theme.font(.small, weight: .semibold))
                    Spacer(minLength: Theme.space(.s8))
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(Self.elapsed(context.date.timeIntervalSince(since)))
                            .font(Theme.font(.label))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                track

                Text("Resumindo o histórico para liberar contexto")
                    .font(Theme.font(.label))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Theme.space(.s14))
        .frame(maxWidth: 440, alignment: .leading)
        .card(border: Theme.accent.opacity(0.3))
        .onAppear {
            phase = 0
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
        .accessibilityLabel("Compactando a conversa")
    }

    private var track: some View {
        GeometryReader { geometry in
            let full = geometry.size.width
            let highlight = max(56, full * 0.36)
            Capsule()
                .fill(Theme.hoverRaised)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(
                            colors: [Theme.accent.opacity(0),
                                     Theme.accent.opacity(0.85),
                                     Theme.accent.opacity(0)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: highlight)
                        .offset(x: -highlight + (full + highlight) * phase)
                }
                .clipShape(Capsule())
        }
        .frame(height: Theme.size(.s5))
    }

    private static func elapsed(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration))
        return seconds < 60 ? "\(seconds)s" : "\(seconds / 60)min \(seconds % 60)s"
    }
}

struct CompactionMark: View {
    let text: String

    var body: some View {
        HStack(spacing: Theme.space(.s10)) {
            rule
            HStack(spacing: Theme.space(.s6)) {
                Theme.image(.compact)
                    .font(Theme.font(.mini, weight: .semibold))
                Text(text)
                    .font(Theme.font(.label, weight: .medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(Theme.textTertiary)
            .padding(.horizontal, Theme.space(.s12))
            .padding(.vertical, Theme.space(.s6))
            .background(Theme.raised, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.border, lineWidth: Theme.line(.thin)))
            rule
        }
        .frame(maxWidth: .infinity)
        .help("A partir daqui a IA só enxerga o resumo do que veio antes")
    }

    private var rule: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(height: Theme.line(.thin))
    }
}

struct DigestRow: View {
    let title: String
    let text: String
    let mono: Bool
    let isOpen: Bool
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space(.s6)) {
            Button(action: toggle) {
                HStack(spacing: Theme.space(.s6)) {
                    Theme.image(.next)
                        .font(Theme.font(.tiny, weight: .bold))
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                    Theme.image(mono ? .terminal : .summary)
                        .font(Theme.font(.label))
                    Text(title)
                        .font(Theme.font(.smallPlus, weight: .medium))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Theme.textMuted)
                .padding(.horizontal, Theme.space(.s12))
                .frame(height: Theme.size(.s38))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isOpen ? "Recolher" : "Ver o conteúdo")
            .accessibilityLabel(isOpen ? "Recolher \(title)" : "Expandir \(title)")

            if isOpen {
                body(of: text)
                    .padding(.horizontal, Theme.space(.s14))
                    .padding(.bottom, Theme.space(.s12))
            }
        }
        .card()
    }

    @ViewBuilder
    private func body(of text: String) -> some View {
        let shown = String(text.prefix(20_000))
        if mono {
            Text(shown)
                .font(Theme.font(.small, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            MarkdownText(text: shown)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
