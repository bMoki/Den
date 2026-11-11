import SwiftUI

struct ContextRing: View {
    let chat: ChatModel
    var showsLabel = true

    @State private var showsDetails = false
    @State private var hovering = false

    var body: some View {
        Button { showsDetails.toggle() } label: {
            HStack(spacing: Theme.space(.s7)) {
                ring
                    .frame(width: Theme.size(.s16), height: Theme.size(.s16))
                if showsLabel {
                    Text(shortLabel)
                        .font(Theme.font(.small))
                        .monospacedDigit()
                        .foregroundStyle(level == .calm ? Theme.textTertiary : level.color)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .chipLabel(horizontalPadding: .s8)
            .hoverFill(hovering, selected: showsDetails)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .tip(tooltip)
        .accessibilityLabel("Janela de contexto")
        .accessibilityValue(chat.contextFraction.map(ContextFormat.percent) ?? "sem dados")
        .floating(isPresented: $showsDetails, edge: .top) {
            ContextPanel(chat: chat)
        }
        .onChange(of: showsDetails) { _, shown in
            if shown { Task { await chat.refreshContextUsage() } }
        }
    }

    private var level: ContextLevel { ContextLevel(fraction: chat.contextFraction ?? 0) }

    private var ring: some View {
        let fraction = chat.contextFraction ?? 0
        return ZStack {
            Circle()
                .stroke(Theme.borderControl, lineWidth: Theme.line(.ring))
            Circle()
                .trim(from: 0, to: max(fraction, chat.contextTokens > 0 ? 0.02 : 0))
                .stroke(level.color, style: StrokeStyle(lineWidth: Theme.line(.ring), lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(.easeInOut(duration: 0.4), value: fraction)
    }

    private var shortLabel: String {
        chat.contextFraction.map(ContextFormat.percent) ?? ContextFormat.tokens(chat.contextTokens)
    }

    private var tooltip: String {
        guard let window = chat.contextWindow else {
            return "\(ContextFormat.tokens(chat.contextTokens)) tokens no contexto"
        }
        return "Contexto: \(ContextFormat.summary(used: chat.contextTokens, window: window))"
            + " · clique para ver o que ocupa a janela"
    }
}

extension ContextLevel {
    var color: Color {
        switch self {
        case .calm: Theme.palette.contextLevels.calm
        case .warning: Theme.palette.contextLevels.warning
        case .critical: Theme.palette.contextLevels.critical
        }
    }
}
