import SwiftUI

struct MessageBubble: View {
    enum Style { case user, assistant }

    let text: String
    let moment: Date?
    var style: Style = .assistant
    var markdown: Bool = false
    var images: [Data] = []
    var files: [String] = []
    var onZoom: (Data) -> Void = { _ in }
    var isOpen = true
    var onToggle: (() -> Void)?

    @State private var hovering = false

    var body: some View {
        switch style {
        case .assistant:
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        case .user where Theme.style.boxes == .lines:
            HStack(alignment: .firstTextBaseline, spacing: Theme.space(.s8)) {
                Text("›").font(Theme.font(.body)).foregroundStyle(Theme.accent).accessibilityHidden(true)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .user:
            HStack(alignment: .bottom, spacing: Theme.space(.s8)) {
                timestamp
                    .opacity(hovering ? 1 : 0)
                    .padding(.bottom, Theme.space(.s2))
                content
                    .padding(.horizontal, Theme.space(.s16))
                    .padding(.vertical, Theme.space(.s11))
                    .background(Theme.bubble, in: UnevenRoundedRectangle(
                        topLeadingRadius: Theme.radius(.r16), bottomLeadingRadius: Theme.radius(.r16),
                        bottomTrailingRadius: Theme.radius(.r4), topTrailingRadius: Theme.radius(.r16), style: .continuous))
            }
            .onHover { hovering = $0 }
        }
    }

    private var content: some View {
        let sizes = images.map { ImageCache.displaySize(for: $0) }
        let contentWidth = sizes.map(\.width).max()
        return VStack(alignment: .leading, spacing: Theme.space(.s8)) {
            ForEach(files, id: \.self) { name in
                HStack(spacing: Theme.space(.s7)) {
                    Theme.image(.attachedFile)
                        .font(Theme.font(.small))
                        .foregroundStyle(Theme.accent)
                    Text(name)
                        .font(Theme.font(.smallPlus))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal, Theme.space(.s10))
                .padding(.vertical, Theme.space(.s7))
                .background(Theme.hoverRaised, in: RoundedRectangle(cornerRadius: Theme.radius(.r8)))
            }
            ForEach(Array(images.enumerated()), id: \.offset) { index, data in
                if let image = ImageCache.decodedImage(data) {
                    Image(nsImage: image)
                        .resizable()
                        .frame(width: sizes[index].width, height: sizes[index].height)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radius(.r10)))
                        .onTapGesture {
                            onZoom(data)
                        }
                        .tip("Clique para ampliar")
                }
            }
            Group {
                if let onToggle, !markdown {
                    collapsible(onToggle)
                } else if markdown {
                    MarkdownText(text: visibleText)
                } else if !text.isEmpty {
                    plainText(visibleText)
                }
            }
            .frame(minWidth: images.isEmpty ? nil : max(contentWidth ?? 0, 220),
                   alignment: .leading)
        }
    }

    private func collapsible(_ onToggle: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: Theme.space(.s8)) {
            plainText(isOpen ? visibleText : LongText.preview(text))
                .lineLimit(isOpen ? nil : LongText.previewLines)
                // swiftlint:disable color_outside_palette
                .mask(LinearGradient(colors: isOpen ? [.black, .black]
                                                    : [.black, .black, .black.opacity(0.2)],
                                     startPoint: .top, endPoint: .bottom))
                // swiftlint:enable color_outside_palette
            Button(action: onToggle) {
                HStack(spacing: Theme.space(.s5)) {
                    Theme.image(.expanded)
                        .font(Theme.font(.mini, weight: .semibold))
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                    Text(isOpen ? "Recolher"
                                : "Mostrar tudo · \(LongText.lineLabel(LongText.lineCount(text)))")
                }
                .font(Theme.font(.small, weight: .medium))
                .foregroundStyle(Theme.accent)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .tip(isOpen ? "Recolher mensagem" : "Mostrar a mensagem inteira")
        }
    }

    private var visibleText: String { Self.clipped(text, limit: 12_000) }

    private func plainText(_ string: String) -> some View {
        Text(string)
            .font(Theme.font(.large))
            .lineSpacing(Theme.space(.s2))
            .foregroundStyle(Theme.text)
            .multilineTextAlignment(.leading)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var timestamp: some View {
        if let moment {
            Text(moment, format: .dateTime.hour().minute())
                .font(Theme.font(.caption))
                .monospacedDigit()
                .foregroundStyle(Theme.textTertiary)
        }
    }

    static func clipped(_ text: String, limit: Int = 1_200) -> String {
        guard text.utf8.count > limit else { return text }
        let head = String(text.prefix(limit))
        let hidden = text.count - head.count
        guard hidden > 0 else { return text }
        return head + "\n⋯ +\(hidden) caracteres não exibidos"
    }
}
