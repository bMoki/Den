import CodeEditSourceEditor
import SwiftUI

struct EditorView: View {
    @Bindable var document: EditorDocument
    let folder: URL

    var body: some View {
        VStack(spacing: 0) {
            bar
            if let problem = document.problem {
                DialogWarning(title: "Não consegui salvar.", detail: problem)
                    .padding(EdgeInsets(top: 10, leading: 14, bottom: 0, trailing: 14))
                    .onTapGesture { document.problem = nil }
            }
            if document.changedOnDisk != nil {
                changedBanner
                    .padding(EdgeInsets(top: 10, leading: 14, bottom: 0, trailing: 14))
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.canvas)
        .task(id: document.url) { await document.watch() }
    }

    private var changedBanner: some View {
        DialogWarning(title: "Este arquivo mudou no disco.", detail: "Você tem alterações não salvas aqui.") {
            HStack(spacing: 6) {
                secondaryButton(perform: document.reloadFromDisk) { Text("Recarregar") }
                secondaryButton(perform: document.compareWithDisk) { Text("Comparar") }
                    .accessibilityAddTraits(document.mode == .compare ? .isSelected : [])
                secondaryButton(perform: document.keepMine) { Text("Manter a minha") }
            }
        }
    }

    private func secondaryButton(perform: @escaping () -> Void, @ViewBuilder label: () -> some View) -> some View {
        Button(action: perform) {
            label()
                .font(.system(size: 12.5))
                .fixedSize()
                .padding(.horizontal, 10)
                .frame(height: 28)
        }
        .buttonStyle(.denSecondary)
    }

    private var bar: some View {
        HStack(spacing: 6) {
            path
            Spacer(minLength: 8)
            if document.kind == .text {
                if document.isMarkdown {
                    barButton("Visualizar", symbol: "eye", isOn: document.mode == .preview) { document.toggle(.preview) }
                }
                barButton("Buscar", symbol: "magnifyingglass", hint: "⌘F", isOn: document.editorState.findPanelVisible == true && document.mode == .code,
                          perform: document.toggleFind)
                    .onKeyboardShortcut("f", modifiers: .command, perform: document.showFind)
                barButton("Diff com o git", symbol: "plus.forwardslash.minus", isOn: document.mode == .diff) { document.toggle(.diff) }
                secondaryButton(perform: document.save) {
                    HStack(spacing: 6) {
                        Text("Salvar")
                        Text("⌘S").font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.textTertiary)
                    }
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!document.isDirty)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .frame(height: 38)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
    }

    private var path: some View {
        Text(crumbs)
            .font(.system(size: 12, design: .monospaced))
            .lineLimit(1)
            .truncationMode(.head)
            .help(document.url.path)
    }

    private var crumbs: AttributedString {
        var line = AttributedString()
        for folder in relativeFolders {
            var part = AttributedString(folder)
            part.foregroundColor = Theme.textTertiary
            var separator = AttributedString(" / ")
            separator.foregroundColor = Theme.textFaint
            line += part + separator
        }
        var name = AttributedString(document.name)
        name.foregroundColor = Theme.textSecondary
        name.font = .system(size: 12, weight: .medium, design: .monospaced)
        return line + name
    }

    private var relativeFolders: [String] {
        let base = folder.standardizedFileURL.path
        let parent = document.url.deletingLastPathComponent().path
        guard parent == base || parent.hasPrefix(base + "/") else { return [parent] }
        return [folder.lastPathComponent] + parent.dropFirst(base.count).split(separator: "/").map(String.init)
    }

    private func barButton(_ title: String, symbol: String, hint: String? = nil, isOn: Bool, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 11.5, weight: .medium))
                Text(title)
                if let hint {
                    Text(hint).font(.system(size: 11, design: .monospaced)).foregroundStyle(Theme.textTertiary)
                }
            }
            .font(.system(size: 12.5))
            .fixedSize()
            .foregroundStyle(isOn ? Theme.accentSoft : Theme.text)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(isOn ? Theme.accentFill : .clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.denGhost)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    @ViewBuilder
    private var content: some View {
        switch document.kind {
        case .loading:
            ProgressView().controlSize(.small)
        case .unreadable(let reason):
            notice(reason, symbol: "doc")
        case .image(let data):
            if let image = NSImage(data: data) {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .padding(24)
                }
                .defaultScrollAnchor(.center)
            } else {
                notice("Não consegui abrir esta imagem.", symbol: "photo")
            }
        case .text:
            switch document.mode {
            case .code:
                SourceEditor($document.text, language: document.language, configuration: .den, state: $document.editorState)
                    .id("\(document.url.path)#\(document.editorGeneration)")
            case .preview:
                ScrollView {
                    MarkdownText(text: document.text)
                        .frame(maxWidth: 720, alignment: .leading)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 28)
                        .frame(maxWidth: .infinity)
                }
            case .diff:
                diff
            case .compare:
                comparison
            }
        }
    }

    @ViewBuilder
    private var diff: some View {
        switch document.diff {
        case nil:
            ProgressView().controlSize(.small)
        case .failed:
            notice("Não consegui calcular o diff com o git.", symbol: "exclamationmark.triangle")
        case .outsideGit:
            notice("Este arquivo não está num repositório git.", symbol: "plus.forwardslash.minus")
        case .unchanged:
            notice("Sem diferenças com o último commit.", symbol: "checkmark")
        case .lines(let lines):
            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(SyntaxHighlighter.render(lines, language: SyntaxHighlighter.language(forFile: document.name))) { line in
                            GitDiffRow(line: line, wraps: false)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 4)
                    .frame(minWidth: proxy.size.width, minHeight: proxy.size.height, alignment: .topLeading)
                    .textSelection(.enabled)
                }
            }
        }
    }

    private var comparison: some View {
        HStack(spacing: 0) {
            compareColumn("No editor (não salvo)", text: document.text)
            Rectangle().fill(Theme.border).frame(width: 1)
            compareColumn("No disco", text: document.changedOnDisk ?? "")
        }
    }

    private func compareColumn(_ title: String, text: String) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
            SourceEditor(.constant(text), language: document.language, configuration: .denReadOnly, state: .constant(SourceEditorState()))
                .id("\(title)#\(text.hashValue)")
        }
        .frame(maxWidth: .infinity)
    }

    private func notice(_ text: String, symbol: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 22))
                .foregroundStyle(Theme.textFaint)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textTertiary)
        }
        .multilineTextAlignment(.center)
        .padding(30)
        .accessibilityElement(children: .combine)
    }
}
