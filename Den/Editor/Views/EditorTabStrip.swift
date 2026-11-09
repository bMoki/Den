import SwiftUI

struct EditorTabStrip: View {
    enum Home {
        case session, page

        var title: String { self == .session ? "Sessão" : "Página" }
        var symbol: String { self == .session ? "bubble.left" : "list.bullet" }
    }

    let tabs: EditorTabs
    let row: SidebarRow
    let files: FileTree
    let home: Home

    @State private var closing: EditorDocument?

    var body: some View {
        let selected = tabs.selection(in: row)
        ScrollViewReader { reader in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    tab(title: home.title, symbol: home.symbol, isOn: selected == nil) { tabs.select(nil, in: row) }
                    ForEach(tabs.documents(in: row)) { document in
                        EditorTab(document: document, mark: files.marks.state(ofFile: document.url),
                                  isOn: selected === document,
                                  select: { tabs.select(document, in: row) },
                                  close: { document.isDirty ? (closing = document) : tabs.close(document, in: row) })
                            .id(document.url)
                    }
                }
                .padding(.leading, 6)
            }
            .onChange(of: selected?.url, initial: true) { _, url in
                guard let url else { return }
                withAnimation(.easeOut(duration: 0.15)) { reader.scrollTo(url) }
            }
        }
        .frame(height: 36)
        .background(Theme.panel)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: 1) }
        .confirmationDialog("Fechar \(closing?.name ?? "") sem salvar?", isPresented: Binding(get: { closing != nil }, set: { if !$0 { closing = nil } })) {
            Button("Salvar e fechar") { finishClosing(saving: true) }
            Button("Fechar sem salvar", role: .destructive) { finishClosing(saving: false) }
            Button("Cancelar", role: .cancel) { closing = nil }
        } message: {
            Text("As alterações não salvas deste arquivo se perdem.")
        }
    }

    private func finishClosing(saving: Bool) {
        guard let document = closing else { return }
        closing = nil
        if saving {
            document.save()
            guard !document.isDirty else {
                tabs.select(document, in: row)
                return
            }
        }
        tabs.close(document, in: row)
    }

    private func tab(title: String, symbol: String, isOn: Bool, select: @escaping () -> Void) -> some View {
        Button(action: select) {
            HStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 11))
                Text(title).font(.system(size: 12.5))
            }
            .editorTabLabel(isOn: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}

private struct EditorTab: View {
    let document: EditorDocument
    let mark: GitFileState?
    let isOn: Bool
    var select: () -> Void
    var close: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 7) {
            Button(action: select) {
                HStack(spacing: 7) {
                    Image(systemName: FileTreeMark.isImage(document.name) ? "photo" : "doc").font(.system(size: 11))
                    Text(document.name).font(.system(size: 12.5))
                    if let mark {
                        Text(FileTreeMark.letter(mark))
                            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                            .foregroundStyle(mark.color)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
            Button(action: close) {
                ZStack {
                    if document.isDirty, !hovering {
                        Circle().fill(Theme.textSecondary).frame(width: 7, height: 7)
                    } else {
                        Image(systemName: "xmark").font(.system(size: 9, weight: .semibold))
                    }
                }
                .frame(width: 16, height: 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.denGhost(radius: 4))
            .help(document.isDirty ? "Não salvo" : "Fechar")
            .accessibilityLabel(document.isDirty ? "Fechar \(document.name), não salvo" : "Fechar \(document.name)")
        }
        .editorTabLabel(isOn: isOn, trailing: 8)
        .onHover { hovering = $0 }
    }
}

private extension View {
    func editorTabLabel(isOn: Bool, trailing: CGFloat = 12) -> some View {
        foregroundStyle(isOn ? Theme.text : Theme.textTertiary)
            .padding(.leading, 12)
            .padding(.trailing, trailing)
            .frame(maxHeight: .infinity)
            .background(isOn ? Theme.canvas : .clear)
            .overlay(alignment: .top) { if isOn { Rectangle().fill(Theme.accent).frame(height: 2) } }
            .overlay(alignment: .trailing) { Rectangle().fill(Theme.border).frame(width: 1) }
            .contentShape(Rectangle())
    }
}
