import SwiftUI

struct EditorTabStrip: View {
    enum Home {
        case session, page

        var title: String { self == .session ? "Sessão" : "Página" }
        var symbol: Icon { self == .session ? .session : .list }
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
                .padding(.leading, Theme.space(.s6))
            }
            .onChange(of: selected?.url, initial: true) { _, url in
                guard let url else { return }
                withAnimation(.easeOut(duration: 0.15)) { reader.scrollTo(url) }
            }
        }
        .frame(height: Theme.size(.s36))
        .background(Theme.panel)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.border).frame(height: Theme.line(.thin)) }
        .confirmation("Fechar \(closing?.name ?? "") sem salvar?",
                      isPresented: Binding(get: { closing != nil }, set: { if !$0 { closing = nil } }),
                      message: "As alterações não salvas deste arquivo se perdem.", choices: [
                          ConfirmationChoice(title: "Salvar e fechar") { finishClosing(saving: true) },
                          ConfirmationChoice(title: "Fechar sem salvar", isDestructive: true) {
                              finishClosing(saving: false)
                          },
                      ])
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

    private func tab(title: String, symbol: Icon, isOn: Bool, select: @escaping () -> Void) -> some View {
        Button(action: select) {
            HStack(spacing: Theme.space(.s7)) {
                Theme.image(symbol).font(Theme.font(.caption))
                Text(title).font(Theme.font(.smallPlus))
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
        HStack(spacing: Theme.space(.s7)) {
            Button(action: select) {
                HStack(spacing: Theme.space(.s7)) {
                    Theme.image(FileTreeMark.isImage(document.name) ? .image : .file).font(Theme.font(.caption))
                    Text(document.name).font(Theme.font(.smallPlus))
                    if let mark {
                        Text(FileTreeMark.letter(mark))
                            .font(Theme.font(.labelPlus, weight: .semibold, design: .monospaced))
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
                        Theme.circle.fill(Theme.textSecondary).frame(width: Theme.size(.s7), height: Theme.size(.s7))
                    } else {
                        Theme.image(.close).font(Theme.font(.mini, weight: .semibold))
                    }
                }
                .frame(width: Theme.style.marks == .characters ? nil : Theme.size(.s16), height: Theme.size(.s16))
                .contentShape(Rectangle())
            }
            .buttonStyle(.thalamusGhost(radius: .r4))
            .tip(document.isDirty ? "Não salvo" : "Fechar")
            .accessibilityLabel(document.isDirty ? "Fechar \(document.name), não salvo" : "Fechar \(document.name)")
        }
        .editorTabLabel(isOn: isOn, trailing: 8)
        .onHover { hovering = $0 }
    }
}

private extension View {
    func editorTabLabel(isOn: Bool, trailing: CGFloat = 12) -> some View {
        foregroundStyle(isOn ? Theme.text : Theme.textTertiary)
            .padding(.leading, Theme.space(.s12))
            .padding(.trailing, trailing)
            .frame(maxHeight: .infinity)
            .background(isOn ? Theme.canvas : .clear)
            .overlay(alignment: .top) { if isOn { Rectangle().fill(Theme.accent).frame(height: Theme.size(.s2)) } }
            .overlay(alignment: .trailing) { Rectangle().fill(Theme.border).frame(width: Theme.line(.thin)) }
            .contentShape(Rectangle())
    }
}
