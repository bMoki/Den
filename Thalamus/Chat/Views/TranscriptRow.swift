import SwiftUI
import HarnessCore

struct TranscriptRow: View {
    let line: ChatLine
    @Binding var expanded: Set<UUID>
    var onZoom: (Data) -> Void

    var body: some View { row(line) }

    @ViewBuilder
    private func row(_ line: ChatLine) -> some View {
        switch line.role {
        case .user:
            userBubble(line)

        case .assistant:
            MessageBubble(text: line.text, moment: line.timestamp,
                          style: .assistant, markdown: true)

        case .thinking:
            HStack(alignment: .top, spacing: Theme.space(.s8)) {
                Theme.image(.thinking)
                    .font(Theme.font(.caption))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: Theme.size(.s14))
                    .padding(.top, Theme.space(.s2))
                Text(MessageBubble.clipped(line.text))
                    .font(Theme.font(.body))
                    .italic()
                    .foregroundStyle(Theme.textMuted)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .tool:
            step(line)

        case .toolResult:
            HStack(alignment: .top, spacing: Theme.space(.s8)) {
                Theme.image(.reply)
                    .font(Theme.font(.label, weight: .medium))
                    .foregroundStyle(Theme.textFaint)
                    .frame(width: Theme.size(.s14))
                    .padding(.top, Theme.space(.s2))
                Text(MessageBubble.clipped(line.text))
                    .font(Theme.font(.captionPlus, design: .monospaced))
                    .foregroundStyle(line.text.hasPrefix("falhou")
                                     ? Theme.removed : Theme.textTertiary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

        case .notice:
            HStack(alignment: .top, spacing: Theme.space(.s8)) {
                Theme.image(.info)
                    .font(Theme.font(.caption))
                    .frame(width: Theme.size(.s14))
                    .padding(.top, Theme.space(.s1))
                Text(MessageBubble.clipped(line.text))
                    .font(Theme.font(.smallPlus))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.textTertiary)

        case .compaction:
            CompactionMark(text: line.text)

        case .digest:
            DigestRow(title: line.title ?? Digest.summary,
                      text: line.text,
                      mono: line.title == Digest.command,
                      isOpen: expanded.contains(line.id)) { toggle(line.id) }

        case .unknown:
            EmptyView()
        }
    }

    private func userBubble(_ line: ChatLine) -> some View {
        VStack(alignment: .trailing, spacing: Theme.space(.s4)) {
            HStack(spacing: 0) {
                Spacer(minLength: Theme.style.boxes == .lines ? 0 : Theme.space(.s96))
                MessageBubble(text: line.text, moment: line.timestamp,
                              style: .user,
                              images: line.images, files: line.files, onZoom: onZoom,
                              isOpen: expanded.contains(line.id),
                              onToggle: LongText.isLong(line.text) ? { toggle(line.id) } : nil)
                    .opacity(line.isQueued ? 0.6 : 1)
            }
            if line.isQueued {
                Label("Na fila · ↑ para editar", icon: .queued)
                    .font(Theme.font(.caption))
                    .foregroundStyle(Theme.textTertiary)
                    .accessibilityIdentifier("queued-message")
            }
        }
    }

    private func toggle(_ id: UUID) {
        withAnimation(.easeOut(duration: 0.15)) {
            if expanded.contains(id) {
                expanded.remove(id)
            } else {
                expanded.insert(id)
            }
        }
    }

    private func step(_ line: ChatLine) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.space(.s8)) {
            Theme.image(Self.icon(for: line.verb))
                .font(Theme.font(.caption, weight: .medium))
                .foregroundStyle(Theme.textMuted)
                .frame(width: Theme.size(.s14))
            let verb = Text(Self.verb(for: line.verb)).foregroundStyle(Theme.textMuted)
            let detail = Text(MessageBubble.clipped(line.text))
                .font(Theme.font(.small, design: .monospaced))
                .foregroundStyle(Theme.text)
            Text("\(verb) \(detail)")
                .font(Theme.font(.body))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    static func icon(for verb: CanonicalTool?) -> Icon {
        switch verb {
        case .read: .read
        case .write: .write
        case .edit: .edit
        case .execute: .terminal
        case .search: .search
        case .fetch: .fetch
        case nil: .tool
        }
    }

    static func verb(for verb: CanonicalTool?) -> String {
        switch verb {
        case .read: "Leu"
        case .write: "Criou"
        case .edit: "Editou"
        case .execute: "Executou"
        case .search: "Buscou"
        case .fetch: "Acessou"
        case nil: "Usou"
        }
    }
}
