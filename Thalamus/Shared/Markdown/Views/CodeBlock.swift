import SwiftUI
import AppKit

struct CodeBlock: View {
    let code: String
    let language: String?

    @State private var hovering = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(MarkdownText.highlighted(code, language: language)) { line in
                Text(line.text)
                    .font(Theme.font(.smallPlus, design: .monospaced))
                    .lineSpacing(Theme.space(.s2))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, Theme.space(.s14))
        .padding(.vertical, Theme.space(.s12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.terminal, in: RoundedRectangle(cornerRadius: Theme.radius(.r10), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius(.r10), style: .continuous)
            .strokeBorder(Theme.border, lineWidth: Theme.line(.thin)))
        .overlay(alignment: .topTrailing) {
            if hovering { copyButton }
        }
        .onHover { hovering = $0 }
    }

    private var copyButton: some View {
        Button(action: copy) {
            Theme.image(copied ? .done : .copy)
                .font(Theme.font(.caption))
                .foregroundStyle(copied ? Theme.added : Theme.textSecondary)
                .frame(width: Theme.size(.s26), height: Theme.size(.s26))
                .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.radius(.r7)))
                .overlay(RoundedRectangle(cornerRadius: Theme.radius(.r7))
                    .strokeBorder(Theme.borderControl, lineWidth: Theme.line(.thin)))
        }
        .buttonStyle(.plain)
        .padding(Theme.space(.s6))
        .help("Copiar código")
        .accessibilityLabel("Copiar código")
    }

    private func copy() {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(code, forType: .string)
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}
