import SwiftUI
import AppKit
import HarnessCore

struct ChatComposer: View {
    @Bindable var chat: ChatModel
    let slash: SlashController
    let mentions: MentionController
    let keys: ChatKeyMonitor
    var stickToBottom: () -> Void

    @State private var focusRequested = false

    private static let placeholder = "Peça uma alteração…"

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space(.s8)) {
            slashSuggestions
            mentionSuggestions

            if !chat.pendingAttachments.isEmpty || !chat.pendingPastes.isEmpty {
                pendingAttachmentRow
            }

            ComposerField(chat: chat, focusRequested: $focusRequested,
                          placeholder: Self.placeholder, submit: submit,
                          stickToBottom: stickToBottom)
                .padding(.horizontal, Theme.space(.s8))
                .padding(.top, Theme.space(.s6))
                .padding(.bottom, Theme.space(.s4))

            ViewThatFits(in: .horizontal) {
                controls(.full)
                controls(.medium)
                controls(.compact)
            }
        }
        .padding(Theme.space(.s8))
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: Theme.radius(.r16), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius(.r16), style: .continuous)
            .strokeBorder(Theme.borderControl, lineWidth: Theme.line(.thin)))
        .elevation(.composer)
        .overlay(alignment: .topLeading) { ComposerStatusChip(chat: chat, keys: keys) }
        .composerColumn()
    }

    enum Density { case full, medium, compact }

    private func controls(_ density: Density) -> some View {
        HStack(spacing: Theme.space(.s6)) {
            LocationChip(chat: chat, compact: density == .compact)
            ForEach(chat.knobs.filter { $0.category == .mode }) {
                KnobBadge(knob: $0, chat: chat, compact: density != .full)
            }
            Spacer(minLength: Theme.space(.s6))
            if chat.contextTokens > 0 || chat.contextWindow != nil {
                ContextRing(chat: chat, showsLabel: density != .compact)
            }
            ForEach(chat.knobs.filter { $0.category != .mode }) { knob in
                if knob.category == .effort, EffortPicker.fits(knob) {
                    EffortPicker(knob: knob, chat: chat, showsLabel: density != .compact)
                } else {
                    KnobBadge(knob: knob, chat: chat, compact: density != .full)
                }
            }
            Button(action: attachFiles) {
                Theme.image(.attach)
                    .font(Theme.font(.headline))
                    .foregroundStyle(Theme.textSecondary)
                    .iconLabel(size: .s32)
            }
            .buttonStyle(.thalamusGhost(radius: .r9))
            .tip("Anexar arquivos")
            .accessibilityLabel("Anexar arquivos")
            sendButton
        }
    }

    private var sendButton: some View {
        Button {
            if chat.isBusy {
                Task { await chat.stop() }
            } else {
                submit()
            }
        } label: {
            Theme.image(chat.isBusy ? .stop : .send)
                .font(Theme.font(chat.isBusy ? .small : .headline, weight: .bold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: Theme.size(.s34), height: Theme.size(.s34))
        }
        .buttonStyle(ThalamusButtonStyle(kind: .primary, radius: .r10))
        .disabled(!chat.isBusy
                  && chat.prompt.trimmingCharacters(in: .whitespaces).isEmpty
                  && chat.pendingAttachments.isEmpty
                  && chat.pendingPastes.isEmpty)
        .tip(chat.isBusy ? "Parar o que está rodando" : "Enviar mensagem")
        .accessibilityLabel(chat.isBusy ? "Parar" : "Enviar mensagem")
    }

    @ViewBuilder
    private var slashSuggestions: some View {
        let matches = slash.matches(prompt: chat.prompt, catalog: chat.catalog)
        if !matches.isEmpty {
            SlashCommandList(commands: matches,
                             selection: min(slash.selection, matches.count - 1),
                             group: slash.group,
                             choose: { if slash.run($0, in: chat) { stickToBottom() } },
                             back: { slash.leaveGroup(in: chat) })
                .padding(Theme.space(.s4))
                .background(Theme.canvas.opacity(0.5),
                            in: RoundedRectangle(cornerRadius: Theme.radius(.r11), style: .continuous))
        }
    }

    @ViewBuilder
    private var mentionSuggestions: some View {
        let matches = mentions.matches(prompt: chat.prompt)
        if !matches.isEmpty {
            let selected = min(mentions.selection, matches.count - 1)
            VStack(alignment: .leading, spacing: Theme.space(.s1)) {
                ForEach(Array(matches.enumerated()), id: \.element.id) { index, candidate in
                    HStack(spacing: Theme.space(.s8)) {
                        Theme.image(candidate.isDirectory ? .folder : .read)
                            .font(Theme.font(.caption))
                            .frame(width: Theme.size(.s14))
                            .foregroundStyle(index == selected ? Theme.accent : Theme.textTertiary)
                        Text(candidate.path)
                            .font(Theme.font(.small, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, Theme.space(.s10))
                    .frame(height: Theme.size(.s28))
                    .background(index == selected ? Theme.hoverRaised : .clear,
                                in: RoundedRectangle(cornerRadius: Theme.radius(.r7), style: .continuous))
                    .foregroundStyle(index == selected ? Theme.text : Theme.textSecondary)
                    .contentShape(Rectangle())
                    .onTapGesture { mentions.accept(candidate, in: chat) }
                }
            }
            .padding(Theme.space(.s4))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.canvas.opacity(0.5),
                        in: RoundedRectangle(cornerRadius: Theme.radius(.r11), style: .continuous))
        }
    }

    private func submit() {
        let text = chat.prompt
        chat.prompt = ""
        stickToBottom()
        Task { await chat.send(text: text) }
    }

    private var pendingAttachmentRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.space(.s8)) {
                ForEach(chat.pendingAttachments) { pending in
                    if pending.isImage, let image = ImageCache.decodedImage(pending.data) {
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: Theme.size(.s56), height: Theme.size(.s56))
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radius(.r9)))
                            .overlay(RoundedRectangle(cornerRadius: Theme.radius(.r9))
                                .strokeBorder(Theme.borderStrong, lineWidth: Theme.line(.thin)))
                            .overlay(alignment: .topTrailing) {
                                removeButton(help: "Remover imagem") {
                                    chat.removeAttachment(pending.id)
                                }
                            }
                    } else {
                        HStack(spacing: Theme.space(.s7)) {
                            Theme.image(.attachedFile)
                                .font(Theme.font(.large))
                                .foregroundStyle(Theme.accent)
                            Text(pending.name ?? "arquivo")
                                .font(Theme.font(.small))
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .frame(maxWidth: 160, alignment: .leading)
                        }
                        .padding(.horizontal, Theme.space(.s12))
                        .frame(height: Theme.size(.s56))
                        .background(Theme.hover, in: RoundedRectangle(cornerRadius: Theme.radius(.r9)))
                        .overlay(alignment: .topTrailing) {
                            removeButton(help: "Remover arquivo") {
                                chat.removeAttachment(pending.id)
                            }
                        }
                    }
                }
                ForEach(chat.pendingPastes) { pasteChip($0) }
            }
            .padding(.top, Theme.space(.s2))
            .padding(.horizontal, Theme.space(.s4))
        }
        .frame(height: Theme.size(.s62))
    }

    private func pasteChip(_ paste: PastedText) -> some View {
        Button {
            chat.expandPaste(paste.id)
            focusRequested = true
        } label: {
            VStack(alignment: .leading, spacing: Theme.space(.s2)) {
                HStack(spacing: Theme.space(.s5)) {
                    Theme.image(.attachment)
                        .foregroundStyle(Theme.accent)
                    Text("Texto colado")
                        .fontWeight(.medium)
                }
                .font(Theme.font(.captionPlus))
                Text(paste.headline)
                    .font(Theme.font(.labelPlus, design: .monospaced))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(LongText.lineLabel(paste.lineCount))
                    .font(Theme.font(.labelPlus))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding(.horizontal, Theme.space(.s10))
            .frame(width: 170, height: Theme.size(.s56), alignment: .leading)
            .background(Theme.hover, in: RoundedRectangle(cornerRadius: Theme.radius(.r9)))
            .contentShape(RoundedRectangle(cornerRadius: Theme.radius(.r9)))
        }
        .buttonStyle(.plain)
        .tip("Clique para mostrar o texto inteiro no campo")
        .overlay(alignment: .topTrailing) {
            removeButton(help: "Remover texto colado") { chat.removePaste(paste.id) }
        }
    }

    private func removeButton(help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Theme.image(.clearSearch)
                .font(Theme.font(.large))
                .foregroundStyle(Theme.text, Theme.canvas.opacity(0.85))
        }
        .buttonStyle(.plain)
        .padding(Theme.space(.s3))
        .tip(help)
        .accessibilityLabel(help)
    }

    private func attachFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.prompt = "Anexar"
        panel.directoryURL = chat.workingDirectory
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if Self.imageExtensions.contains(url.pathExtension.lowercased()),
               let image = NSImage(contentsOf: url),
               let tiff = image.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiff),
               let png = bitmap.representation(using: .png, properties: [:]) {
                chat.attach(imageData: png)
            } else if url.pathExtension.lowercased() == "pdf",
                      let data = try? Data(contentsOf: url) {
                chat.attach(fileData: data, name: url.lastPathComponent,
                               mediaType: "application/pdf")
            } else {
                mentionPath(for: url)
            }
        }
    }

    private func mentionPath(for url: URL) {
        let root = chat.workingDirectory.path
        let path = url.path.hasPrefix(root + "/")
            ? String(url.path.dropFirst(root.count + 1))
            : url.path
        var prompt = chat.prompt
        if !prompt.isEmpty, !prompt.hasSuffix(" ") { prompt += " " }
        chat.prompt = prompt + "@" + path + " "
    }

    private static let imageExtensions: Set<String> =
        ["png", "jpg", "jpeg", "gif", "heic", "heif", "webp", "tiff", "bmp"]
}
