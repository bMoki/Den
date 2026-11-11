import SwiftUI
import HarnessCore

struct ToolSteps: View {
    let id: UUID
    let lines: [ChatLine]
    @Binding var expanded: Set<UUID>
    var isLive = false
    var onZoom: (Data) -> Void

    @State private var hovering = false

    private var tools: [ChatLine] { lines.filter { $0.role == .tool } }

    var body: some View {
        let isOpen = expanded.contains(id)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    if isOpen { expanded.remove(id) } else { expanded.insert(id) }
                }
            } label: {
                header(isOpen: isOpen)
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .help(isOpen ? "Recolher os passos" : "Ver o que a IA fez")
            .accessibilityLabel(isOpen ? "Recolher passos" : "Expandir \(lines.count) passos")

            if isOpen {
                Rectangle().fill(Theme.border).frame(height: Theme.line(.thin))
                VStack(alignment: .leading, spacing: Theme.space(.s9)) {
                    ForEach(lines) { line in
                        if line.role == .unknown {
                            Text(line.text)
                                .font(Theme.font(.caption, design: .monospaced))
                                .foregroundStyle(Theme.textTertiary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            TranscriptRow(line: line, expanded: $expanded, onZoom: onZoom)
                        }
                    }
                }
                .padding(.leading, Theme.space(.s14))
                .padding(.trailing, Theme.space(.s14))
                .padding(.vertical, Theme.space(.s12))
            }
        }
        .card()
    }

    private func header(isOpen: Bool) -> some View {
        HStack(spacing: Theme.space(.s10)) {
            ZStack {
                Circle()
                    .fill(isLive ? Theme.action : Theme.hoverRaised)
                    .frame(width: Theme.size(.s22), height: Theme.size(.s22))
                Theme.image(tools.isEmpty ? .thinking : .tool)
                    .font(Theme.font(.label, weight: .semibold))
                    .foregroundStyle(isLive ? Theme.onAction : Theme.textSecondary)
            }
            HStack(spacing: 0) {
                Text(lines.count == 1 ? "1 passo" : "\(lines.count) passos")
                    .fontWeight(.medium)
                    .monospacedDigit()
                if let last = tools.last {
                    Text(" · \(TranscriptRow.verb(for: last.verb)) ")
                        .foregroundStyle(Theme.textTertiary)
                    Text(last.text)
                        .font(Theme.font(.small, design: .monospaced))
                        .foregroundStyle(isLive ? Theme.accentSoft : Theme.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .font(Theme.font(.body))
            .lineLimit(1)
            Spacer(minLength: Theme.space(.s6))
            if isLive {
                LiveDot()
            }
            Theme.image(.expanded)
                .font(Theme.font(.label, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .rotationEffect(.degrees(isOpen ? 180 : 0))
        }
        .padding(.horizontal, Theme.space(.s12))
        .frame(height: Theme.size(.s42))
        .background(hovering ? Theme.hover.opacity(0.6) : .clear,
                    in: UnevenRoundedRectangle(
                        topLeadingRadius: 12, bottomLeadingRadius: isOpen ? 0 : 12,
                        bottomTrailingRadius: isOpen ? 0 : 12, topTrailingRadius: 12,
                        style: .continuous))
        .contentShape(Rectangle())
    }
}

struct LiveDot: View {
    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(Theme.accent)
            .frame(width: Theme.size(.s7), height: Theme.size(.s7))
            .opacity(pulsing ? 0.35 : 1)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulsing)
            .onAppear { pulsing = true }
            .accessibilityLabel("Pensando")
    }
}
