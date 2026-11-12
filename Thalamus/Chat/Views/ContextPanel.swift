import SwiftUI
import HarnessCore

struct ContextPanel: View {
    let chat: ChatModel

    private static let maxListHeight: CGFloat = 440

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space(.s12)) {
            header
            if let usage = chat.contextUsage {
                ContextBar(usage: usage)
                FittedScroll(maxHeight: Self.maxListHeight) {
                    VStack(alignment: .leading, spacing: Theme.space(.s12)) {
                        categories(of: usage)
                        if !usage.details.isEmpty {
                            Rectangle().fill(Theme.border).frame(height: Theme.line(.thin))
                            VStack(alignment: .leading, spacing: Theme.space(.s2)) {
                                ForEach(usage.details, id: \.category) { detail in
                                    DetailGroup(detail: detail)
                                }
                            }
                        }
                    }
                }
                if usage.isEstimate {
                    footnote("A divisão é estimada a partir da conversa; o total vem do \(chat.harnessName).")
                }
                if !chat.isLive {
                    footnote("Última medição desta sessão. Atualiza na próxima mensagem.")
                }
            } else {
                Text(chat.isLive
                     ? "O \(chat.harnessName) ainda não informou o uso do contexto."
                     : "O detalhamento aparece depois da próxima mensagem desta sessão.")
                    .font(Theme.font(.small))
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .padding(Theme.space(.s16))
        .frame(width: 340)
        .foregroundStyle(Theme.text)
        .background(Theme.raised)
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(Theme.font(.caption))
            .foregroundStyle(Theme.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Janela de contexto")
                .font(Theme.font(.body, weight: .semibold))
            Spacer()
            if let window = chat.contextUsage?.windowTokens ?? chat.contextWindow {
                Text(ContextFormat.summary(used: chat.contextUsage?.usedTokens ?? chat.contextTokens,
                                           window: window))
                    .font(Theme.font(.captionPlus, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    private func categories(of usage: ContextUsage) -> some View {
        let ordered = Self.ordered(usage.slices)
        let deferred = ordered.filter(\.isDeferred)
        return VStack(alignment: .leading, spacing: Theme.space(.s7)) {
            ForEach(Array(ordered.filter { !$0.isDeferred }.enumerated()), id: \.offset) { _, slice in
                CategoryRow(slice: slice, window: usage.windowTokens)
            }
            if !deferred.isEmpty {
                Text("Carregadas sob demanda, fora da janela até serem usadas")
                    .font(Theme.font(.caption))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.top, Theme.space(.s4))
                ForEach(Array(deferred.enumerated()), id: \.offset) { _, slice in
                    CategoryRow(slice: slice, window: usage.windowTokens)
                }
            }
        }
    }

    static func ordered(_ slices: [ContextSlice]) -> [ContextSlice] {
        let filled = slices.filter {
            !$0.isDeferred && $0.category != .freeSpace && $0.category != .autocompactBuffer
        }
        return filled.sorted { $0.tokens > $1.tokens }
            + slices.filter { !$0.isDeferred && $0.category == .autocompactBuffer }
            + slices.filter { !$0.isDeferred && $0.category == .freeSpace }
            + slices.filter(\.isDeferred)
    }
}

private struct ContextBar: View {
    let usage: ContextUsage

    var body: some View {
        let filled = ContextPanel.ordered(usage.slices)
            .filter { !$0.isDeferred && $0.category != .freeSpace && $0.tokens > 0 }
        let total = max(usage.windowTokens, filled.reduce(0) { $0 + $1.tokens }, 1)

        GeometryReader { proxy in
            HStack(spacing: Theme.space(.s2)) {
                ForEach(Array(filled.enumerated()), id: \.offset) { _, slice in
                    Rectangle()
                        .fill(slice.category.color)
                        .frame(width: max(Theme.size(.s2), proxy.size.width * CGFloat(slice.tokens) / CGFloat(total)))
                }
                Spacer(minLength: 0)
            }
        }
        .frame(height: Theme.size(.s8))
        .background(Theme.borderStrong)
        .clipShape(Theme.capsule)
    }
}

private struct CategoryRow: View {
    let slice: ContextSlice
    let window: Int

    var body: some View {
        HStack(spacing: Theme.space(.s8)) {
            Swatch(color: slice.category == .freeSpace ? nil
                   : slice.isDeferred ? Theme.borderControl : slice.category.color)
            Text(slice.category.label)
                .foregroundStyle(slice.isDeferred ? Theme.textTertiary : Theme.text)
                .lineLimit(1)
            Spacer(minLength: Theme.space(.s8))
            Text(ContextFormat.tokens(slice.tokens))
                .font(Theme.font(.captionPlus, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
            Text(slice.isDeferred || window == 0
                 ? "—"
                 : ContextFormat.percent(Double(slice.tokens) / Double(window)))
                .font(Theme.font(.captionPlus, design: .monospaced))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: Theme.size(.s48), alignment: .trailing)
        }
        .font(Theme.font(.smallPlus))
    }
}

private struct Disclosure<Label: View, Content: View>: View {
    @ViewBuilder var label: () -> Label
    @ViewBuilder var content: () -> Content

    @State private var isOpen = false
    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space(.s2)) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) { isOpen.toggle() }
            } label: {
                HStack(spacing: Theme.space(.s6)) {
                    Theme.image(.next)
                        .font(Theme.font(.mini, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                        .frame(width: Theme.size(.s10))
                    label()
                }
                .padding(.horizontal, Theme.space(.s6))
                .frame(height: Theme.size(.s26))
                .hoverFill(hovering, radius: .r6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            if isOpen {
                content()
                    .padding(.leading, Theme.space(.s22))
                    .padding(.trailing, Theme.space(.s6))
                    .padding(.bottom, Theme.space(.s4))
            }
        }
    }
}

private struct DetailGroup: View {
    let detail: ContextDetail

    var body: some View {
        Disclosure {
            ItemRow(name: detail.category.label, tokens: detail.tokens,
                    count: detail.items.count)
                .font(Theme.font(.smallPlus, weight: .medium))
        } content: {
            VStack(alignment: .leading, spacing: Theme.space(.s3)) {
                if detail.category == .mcpTools {
                    ForEach(servers, id: \.name) { server in
                        Disclosure {
                            ItemRow(name: server.name, tokens: server.tokens,
                                    count: server.items.count)
                        } content: {
                            items(server.items)
                        }
                    }
                } else {
                    items(detail.items)
                }
            }
        }
        .font(Theme.font(.small))
    }

    private func items(_ list: [ContextItem]) -> some View {
        VStack(alignment: .leading, spacing: Theme.space(.s4)) {
            ForEach(Array(list.sorted { $0.tokens > $1.tokens }.enumerated()), id: \.offset) { _, item in
                ItemRow(name: displayName(of: item), tokens: item.tokens,
                        isDeferred: item.isDeferred)
                    .tip(item.isDeferred ? "\(item.name) · carregada sob demanda" : item.name)
            }
        }
    }

    private func displayName(of item: ContextItem) -> String {
        detail.category == .memoryFiles
            ? (item.name as NSString).abbreviatingWithTildeInPath
            : item.name
    }

    private var servers: [(name: String, items: [ContextItem], tokens: Int)] {
        Dictionary(grouping: detail.items) { $0.group ?? "?" }
            .map { (name: $0.key, items: $0.value, tokens: $0.value.reduce(0) { $0 + $1.tokens }) }
            .sorted { $0.tokens > $1.tokens }
    }
}

private struct ItemRow: View {
    let name: String
    let tokens: Int
    var count: Int?
    var isDeferred = false

    var body: some View {
        HStack(spacing: Theme.space(.s8)) {
            Text(name)
                .foregroundStyle(isDeferred ? Theme.textTertiary : Theme.text)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: Theme.space(.s8))
            Text(ContextFormat.tokens(tokens))
                .font(Theme.font(.captionPlus, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
            if let count {
                Text(String(count))
                    .font(Theme.font(.captionPlus, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: Theme.size(.s28), alignment: .trailing)
            }
        }
    }
}

extension ContextCategory {
    var label: String {
        switch self {
        case .systemPrompt: "Prompt de sistema"
        case .systemTools: "Ferramentas do sistema"
        case .mcpTools: "Ferramentas MCP"
        case .customAgents: "Agentes"
        case .memoryFiles: "Arquivos de memória"
        case .skills: "Skills"
        case .messages: "Mensagens"
        case .toolActivity: "Ferramentas e resultados"
        case .systemAndTools: "Sistema e ferramentas"
        case .autocompactBuffer: "Reserva da autocompactação"
        case .freeSpace: "Espaço livre"
        case .other(let name): name
        }
    }

    var color: Color {
        switch self {
        case .messages: Theme.palette.contextCategories.messages
        case .mcpTools, .toolActivity: Theme.palette.contextCategories.tools
        case .systemTools, .systemAndTools: Theme.palette.contextCategories.system
        case .skills: Theme.palette.contextCategories.skills
        case .customAgents: Theme.palette.contextCategories.agents
        case .memoryFiles: Theme.palette.contextCategories.memory
        case .autocompactBuffer: Theme.palette.contextCategories.autocompactBuffer
        case .freeSpace: .clear
        case .systemPrompt, .other: Theme.palette.contextCategories.systemPrompt
        }
    }
}
