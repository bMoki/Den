import SwiftUI

struct GitDiffRow: View {
    let line: GitDisplayLine
    var wraps = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(line.kind == .hunk ? "⋯" : line.number.map(String.init) ?? "")
                .foregroundStyle(Theme.textFaint)
                .frame(width: Theme.size(.s40), alignment: .trailing)
                .padding(.trailing, Theme.space(.s8))
            Text(sign)
                .foregroundStyle(signColor)
                .frame(width: Theme.size(.s14), alignment: .leading)
            Text(line.text)
                .italic(line.kind == .hunk)
                .foregroundStyle(line.kind == .hunk ? Theme.hunk : Theme.text)
                .fixedSize(horizontal: !wraps, vertical: true)
            Spacer(minLength: Theme.space(.s8))
        }
        .font(Theme.font(.small, design: .monospaced))
        .padding(.vertical, Theme.space(.s1Half))
        .background(background)
    }

    private var sign: String {
        switch line.kind {
        case .added: "+"
        case .removed: "−"
        case .hunk, .context: " "
        }
    }

    private var signColor: Color {
        switch line.kind {
        case .added: Theme.added
        case .removed: Theme.removed
        case .hunk, .context: Theme.textFaint
        }
    }

    private var background: Color {
        switch line.kind {
        case .added: Theme.addedFill
        case .removed: Theme.removedFill
        case .hunk: Theme.hunkFill
        case .context: .clear
        }
    }
}
