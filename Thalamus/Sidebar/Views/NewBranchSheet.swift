import SwiftUI

struct NewBranchSheet: View {
    @Bindable var creation: BranchCreation
    var start: () -> Void
    var retry: (String) -> Void
    var prepareAgain: () -> Void

    @FocusState private var nameFocused: Bool
    @FocusState private var nicknameFocused: Bool

    var body: some View { sheet.dialogBox() }

    private var sheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            if creation.phase == .form { form } else { progress }
        }
        .frame(width: 500)
        .background(Theme.raised)
        .foregroundStyle(Theme.text)
    }

    private var form: some View {
        Group {
            DialogHeading(title: Text("Nova Branch de workspace"),
                          subtitle: Text("O ns cria a branch em cada Repo e prepara banco, aliases e dependências. Nenhum Serviço é iniciado."))
            VStack(alignment: .leading, spacing: Theme.space(.s14)) {
                field("Nome da branch") {
                    TextField("", text: $creation.name)
                        .focused($nameFocused)
                        .onSubmit(start)
                        .dialogField(focused: nameFocused)
                        .accessibilityLabel("Nome da branch")
                }
                nicknameField
                field("Base") {
                    HStack(spacing: Theme.space(.s8)) {
                        Theme.image(.branch)
                            .font(Theme.font(.caption))
                        Text("master")
                            .font(Theme.font(.smallPlus, design: .monospaced))
                        Spacer(minLength: 0)
                        Text("padrão do ns")
                            .font(Theme.font(.small))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, Theme.space(.s11))
                    .frame(height: Theme.size(.s34))
                    .background(Theme.card, in: DialogBox.shape)
                    .overlay(DialogBox.shape.strokeBorder(Theme.border))
                }
                field("Repos") {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: Theme.space(.s6)), GridItem(.flexible())], spacing: Theme.space(.s6)) {
                        ForEach(BranchCreation.Repo.fixed, id: \.self) {
                            DialogCheckbox(title: $0, isOn: .constant(true), note: "sempre", isFixed: true)
                        }
                        ForEach(BranchCreation.Repo.allCases) { repo in
                            DialogCheckbox(title: repo.rawValue, isOn: Binding(
                                get: { creation.repos.contains(repo) },
                                set: { if $0 { creation.repos.insert(repo) } else { creation.repos.remove(repo) } }))
                        }
                    }
                }
            }
            .dialogBody()
            DialogFooter {
                Spacer(minLength: 0)
                DialogCancelButton { creation.isPresented = false }
                Button(action: start) { Text("Criar e preparar").pillLabel() }
                    .buttonStyle(.thalamusPrimary)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!creation.canCreate)
            }
        }
        .onAppear { nameFocused = true }
    }

    @ViewBuilder
    private var progress: some View {
        let wording = Wording(adding: creation.adding)
        DialogHeading(title: Text("\(wording.heading) \(Text(creation.name).font(Theme.font(.large, weight: .semibold, design: .monospaced)))"),
                      subtitle: Text(wording.subtitle))
            VStack(alignment: .leading, spacing: Theme.space(.s14)) {
                VStack(alignment: .leading, spacing: Theme.space(.s2)) {
                    ForEach(creation.steps) { StepRow(step: $0) }
                }
                if let question = creation.question {
                    QuestionBox(question: question, reply: creation.reply)
                }
                ForEach(creation.missing) { missing in
                    FailureBox(title: "\(missing.repo) não foi incluído.",
                               detail: wording.missingDetail,
                               message: missing.message) {
                        if missing.retrying {
                            ProgressView().controlSize(.small)
                        } else {
                            Button { retry(missing.repo) } label: {
                                Text("Repetir \(missing.repo)").pillLabel()
                            }
                                .buttonStyle(.thalamusSecondary)
                        }
                    }
                }
                if let stopped {
                    FailureBox(title: stopped.title, detail: nil,
                               message: stopped.failure.detail) {
                        if case .notPrepared = creation.phase {
                            Button(action: prepareAgain) { Text("Preparar de novo").pillLabel() }
                                .buttonStyle(.thalamusSecondary)
                        }
                    }
                }
            }
            .dialogBody()
            DialogFooter {
                Text(footerNote(wording))
                    .font(Theme.font(.small))
                    .foregroundStyle(Theme.textTertiary)
                Spacer(minLength: 0)
                Button { creation.isPresented = false } label: { Text("Fechar").pillLabel() }
                    .buttonStyle(ThalamusButtonStyle(kind: creation.phase == .finished ? .primary : .secondary))
                    .keyboardShortcut(.cancelAction)
            }
    }

    private var stopped: (title: String, failure: NsFailure)? {
        switch creation.phase {
        case .failed(let failure): ("A criação parou.", failure)
        case .notPrepared(let repo, let failure): ("\(repo) foi incluído, mas a branch não foi preparada.", failure)
        case .form, .running, .finished: nil
        }
    }

    private func footerNote(_ wording: Wording) -> String {
        switch creation.phase {
        case .form, .running: "Preparando…"
        case .finished where creation.missing.isEmpty: wording.finished
        case .finished, .failed, .notPrepared: ""
        }
    }

    private struct Wording {
        let heading: String
        let subtitle: String
        let missingDetail: String
        let finished: String

        init(adding: BranchCreation.Repo?) {
            if let adding {
                heading = "Incluindo \(adding.rawValue) em"
                subtitle = "Pode fechar esta janela; a inclusão continua. O Serviço novo fica Parado."
                missingDetail = "A branch segue sem ele."
                finished = "Pronto. Nenhum Serviço foi iniciado."
            } else {
                heading = "Criando"
                subtitle = "Pode fechar esta janela; a criação continua e aparece na barra lateral."
                missingDetail = "A branch foi mantida sem ele."
                finished = "Pronto. A Sessão abriu na raiz da branch."
            }
        }
    }

    private var nicknameField: some View {
        field("Apelido", note: "opcional",
              counter: creation.nickname.isEmpty ? nil : "\(creation.nickname.count)/\(BranchNickname.maxLength)") {
            TextField("", text: $creation.nickname)
                .focused($nicknameFocused)
                .onSubmit(start)
                .limiting($creation.nickname, to: BranchNickname.maxLength)
                .dialogField(focused: nicknameFocused, design: .default)
                .accessibilityLabel("Apelido, opcional")
        }
    }

    private func field(_ label: String, note: String? = nil, counter: String? = nil,
                       @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.space(.s6)) {
            HStack(spacing: 0) {
                Text(label)
                    .font(Theme.font(.small, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                if let note {
                    Text(" · \(note)")
                        .font(Theme.font(.small))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer(minLength: Theme.space(.s4))
                if let counter {
                    Text(counter)
                        .font(Theme.font(.caption, design: .monospaced))
                        .foregroundStyle(Theme.textTertiary)
                        .accessibilityHidden(true)
                }
            }
            content()
        }
    }

}

private struct StepRow: View {
    let step: BranchCreation.Step

    var body: some View {
        HStack(spacing: Theme.space(.s10)) {
            icon.frame(width: Theme.size(.s18), height: Theme.size(.s18))
            Text(step.title)
                .font(Theme.font(.body))
                .foregroundStyle(step.state == .waiting ? Theme.textTertiary : Theme.textSecondary)
            Spacer(minLength: Theme.space(.s4))
            if let detail = step.detail {
                Text(detail)
                    .font(Theme.font(.captionPlus, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(height: Theme.size(.s30))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var icon: some View {
        switch step.state {
        case .waiting:
            Theme.circle.strokeBorder(Theme.textFaint, style: StrokeStyle(lineWidth: Theme.line(.medium), dash: [2.5, 2.5]))
        case .running:
            ProgressView().controlSize(.mini)
        case .done:
            symbol(.done, Theme.added, on: Theme.addedFill)
        case .failed:
            symbol(.close, Theme.removed, on: Theme.removedFill)
        }
    }

    private func symbol(_ name: Icon, _ color: Color, on fill: Color) -> some View {
        Theme.image(name)
            .font(Theme.font(.mini, weight: .bold))
            .foregroundStyle(color)
            .frame(width: Theme.size(.s18), height: Theme.size(.s18))
            .background(fill, in: Theme.circle)
    }
}

private struct QuestionBox: View {
    let question: NsQuestion
    var reply: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space(.s10)) {
            VStack(alignment: .leading, spacing: Theme.space(.s3)) {
                Text("O ns pergunta")
                    .font(Theme.font(.captionPlus))
                    .foregroundStyle(Theme.textTertiary)
                Text(question.message)
                    .font(Theme.font(.body))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: Theme.space(.s8)) {
                Spacer(minLength: 0)
                Button { reply(false) } label: { Text("Não").pillLabel() }
                    .buttonStyle(ThalamusButtonStyle(kind: question.default ? .secondary : .primary))
                Button { reply(true) } label: { Text("Sim").pillLabel() }
                    .buttonStyle(ThalamusButtonStyle(kind: question.default ? .primary : .secondary))
            }
        }
        .callout(fill: Theme.accentFill, border: Theme.accent)
    }
}

private struct FailureBox<Action: View>: View {
    let title: String
    let detail: String?
    let message: String
    @ViewBuilder var action: () -> Action

    var body: some View {
        HStack(spacing: Theme.space(.s10)) {
            Theme.image(.warning)
                .font(Theme.font(.body))
                .foregroundStyle(Theme.removed)
            VStack(alignment: .leading, spacing: Theme.space(.s2)) {
                Text("\(Text(title).fontWeight(.semibold).foregroundStyle(Theme.removed))\(detail.map { " \($0)" } ?? "")")
                    .font(Theme.font(.smallPlus))
                Text(message)
                    .font(Theme.font(.captionPlus, design: .monospaced))
                    .foregroundStyle(Theme.removed.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
            action()
        }
        .callout(fill: Theme.removedFill, border: Theme.removed)
    }
}

private extension View {
    func callout(fill: Color, border: Color) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.radius(.r12), style: .continuous)
        return padding(EdgeInsets(top: Theme.space(.s12), leading: Theme.space(.s14), bottom: Theme.space(.s12), trailing: Theme.space(.s14)))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(border.opacity(0.45)))
    }
}
