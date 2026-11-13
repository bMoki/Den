import CodeEditSourceEditor
import SwiftUI

struct EditorView: View {
    @Bindable var document: EditorDocument
    let folder: URL
    var close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            bar
            if let problem = document.problem {
                DialogWarning(title: "Não consegui salvar.", detail: problem)
                    .padding(EdgeInsets(top: Theme.space(.s10), leading: Theme.space(.s14), bottom: 0, trailing: Theme.space(.s14)))
                    .onTapGesture { document.problem = nil }
            }
            if let loss = document.lostOnDisk {
                lostBanner(loss)
                    .padding(EdgeInsets(top: Theme.space(.s10), leading: Theme.space(.s14), bottom: 0, trailing: Theme.space(.s14)))
            }
            if document.changedOnDisk != nil {
                changedBanner
                    .padding(EdgeInsets(top: Theme.space(.s10), leading: Theme.space(.s14), bottom: 0, trailing: Theme.space(.s14)))
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Theme.canvas)
        .task(id: document.url) { await document.watch() }
    }

    private var changedBanner: some View {
        DialogWarning(title: "Este arquivo mudou no disco.", detail: "Você tem alterações não salvas aqui.") {
            HStack(spacing: Theme.space(.s6)) {
                secondaryButton(perform: document.reloadFromDisk) { Text("Recarregar") }
                secondaryButton(perform: document.compareWithDisk) { Text("Comparar") }
                    .accessibilityAddTraits(document.mode == .compare ? .isSelected : [])
                secondaryButton(perform: document.keepMine) { Text("Manter a minha") }
            }
        }
    }

    private func lostBanner(_ loss: EditorDocument.DiskLoss) -> some View {
        let unsaved = document.isDirty ? "Você tem alterações não salvas aqui." : "O texto agora só existe aqui."
        let (title, detail) = switch loss {
        case .deleted: ("Este arquivo foi apagado no disco.", unsaved)
        case .unreadable(let reason): ("O arquivo no disco não abre mais aqui.", "\(reason) \(unsaved)")
        }
        return DialogWarning(title: title, detail: detail) {
            HStack(spacing: Theme.space(.s6)) {
                secondaryButton(perform: close) { Text("Fechar") }
                secondaryButton(perform: document.saveAnyway) { Text("Salvar mesmo assim") }
            }
        }
    }

    private func secondaryButton(perform: @escaping () -> Void, @ViewBuilder label: () -> some View) -> some View {
        Button(action: perform) {
            label()
                .font(Theme.font(.smallPlus))
                .fixedSize()
                .padding(.horizontal, Theme.space(.s10))
                .frame(height: Theme.size(.s28))
        }
        .buttonStyle(.thalamusSecondary)
    }

    private var bar: some View {
        HStack(spacing: Theme.space(.s6)) {
            path
            Spacer(minLength: Theme.space(.s8))
            if document.kind == .text {
                if document.isMarkdown {
                    barButton("Visualizar", symbol: .show, isOn: document.mode == .preview) { document.toggle(.preview) }
                }
                barButton("Buscar", symbol: .search, hint: "⌘F", isOn: document.editorState.findPanelVisible == true && document.mode == .code,
                          perform: document.toggleFind)
                    .onKeyboardShortcut("f", modifiers: .command, perform: document.showFind)
                barButton("Diff com o git", symbol: .diff, isOn: document.mode == .diff) { document.toggle(.diff) }
                secondaryButton(perform: document.save) {
                    HStack(spacing: Theme.space(.s6)) {
                        Text("Salvar")
                        Text("⌘S").font(Theme.font(.caption, design: .monospaced)).foregroundStyle(Theme.textTertiary)
                    }
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!document.isDirty || document.lostOnDisk != nil)
            }
        }
        .padding(.leading, Theme.space(.s14))
        .padding(.trailing, Theme.space(.s10))
        .frame(height: Theme.size(.s38))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: Theme.line(.thin)) }
    }

    private var path: some View {
        Text(crumbs)
            .font(Theme.font(.small, design: .monospaced))
            .lineLimit(1)
            .truncationMode(.head)
            .tip(document.url.path)
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
        name.font = Theme.font(.small, weight: .medium, design: .monospaced)
        return line + name
    }

    private var relativeFolders: [String] {
        let base = folder.standardizedFileURL.path
        let parent = document.url.deletingLastPathComponent().path
        guard parent == base || parent.hasPrefix(base + "/") else { return [parent] }
        return [folder.lastPathComponent] + parent.dropFirst(base.count).split(separator: "/").map(String.init)
    }

    private func barButton(_ title: String, symbol: Icon, hint: String? = nil, isOn: Bool, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            HStack(spacing: Theme.space(.s6)) {
                Theme.image(symbol, size: .captionPlus, weight: .medium)
                Text(title)
                if let hint {
                    Text(hint).font(Theme.font(.caption, design: .monospaced)).foregroundStyle(Theme.textTertiary)
                }
            }
            .font(Theme.font(.smallPlus))
            .fixedSize()
            .foregroundStyle(isOn ? Theme.accentSoft : Theme.text)
            .padding(.horizontal, Theme.space(.s10))
            .frame(height: Theme.size(.s28))
            .background(isOn ? Theme.accentFill : .clear, in: RoundedRectangle(cornerRadius: Theme.radius(.r8), style: .continuous))
        }
        .buttonStyle(.thalamusGhost)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    @ViewBuilder
    private var content: some View {
        switch document.kind {
        case .loading:
            ProgressView().controlSize(.small)
        case .unreadable(let reason):
            notice(reason, symbol: .file)
        case .image(let data):
            if let image = NSImage(data: data) {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: image)
                        .padding(Theme.space(.s24))
                }
                .defaultScrollAnchor(.center)
            } else {
                notice("Não consegui abrir esta imagem.", symbol: .image)
            }
        case .text:
            switch document.mode {
            case .code:
                SourceEditor($document.text, language: document.language, configuration: .thalamus, state: $document.editorState,
                             undoManager: document.memory.undoManager, coordinators: [document.memory, EditorClipping.shared])
                    .id("\(document.url.path)#\(document.editorGeneration)")
            case .preview:
                ScrollView {
                    MarkdownText(text: document.text)
                        .frame(maxWidth: 720, alignment: .leading)
                        .padding(.horizontal, Theme.space(.s36))
                        .padding(.vertical, Theme.space(.s28))
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
            notice("Não consegui calcular o diff com o git.", symbol: .warning)
        case .outsideGit:
            notice("Este arquivo não está num repositório git.", symbol: .diff)
        case .unchanged:
            notice("Sem diferenças com o último commit.", symbol: .done)
        case .lines(let lines):
            GeometryReader { proxy in
                ScrollView([.horizontal, .vertical]) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(SyntaxHighlighter.render(lines, language: SyntaxHighlighter.language(forFile: document.name))) { line in
                            GitDiffRow(line: line, wraps: false)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, Theme.space(.s4))
                    .frame(minWidth: proxy.size.width, minHeight: proxy.size.height, alignment: .topLeading)
                    .textSelection(.enabled)
                }
            }
        }
    }

    private var comparison: some View {
        HStack(spacing: 0) {
            compareColumn("No editor (não salvo)", text: document.text)
            Rectangle().fill(Theme.border).frame(width: Theme.line(.thin))
            compareColumn("No disco", text: document.changedOnDisk ?? "")
        }
    }

    private func compareColumn(_ title: String, text: String) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(Theme.font(.captionPlus, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, Theme.space(.s14))
                .frame(maxWidth: .infinity, minHeight: Theme.size(.s32), alignment: .leading)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: Theme.line(.thin)) }
            SourceEditor(.constant(text), language: document.language, configuration: .thalamusReadOnly, state: .constant(SourceEditorState()),
                         coordinators: [EditorClipping.shared])
                .id("\(title)#\(text.hashValue)")
        }
        .frame(maxWidth: .infinity)
    }

    private func notice(_ text: String, symbol: Icon) -> some View {
        VStack(spacing: Theme.space(.s8)) {
            Theme.image(symbol, size: .title)
                .foregroundStyle(Theme.textFaint)
            Text(text)
                .font(Theme.font(.body))
                .foregroundStyle(Theme.textTertiary)
        }
        .multilineTextAlignment(.center)
        .padding(Theme.space(.s30))
        .accessibilityElement(children: .combine)
    }
}
