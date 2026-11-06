import SwiftUI

struct NewBranchSheet: View {
    @Bindable var creation: BranchCreation
    var start: () -> Void

    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if creation.phase == .form { form } else { progress }
        }
        .frame(width: 500)
        .background(Theme.raised)
        .foregroundStyle(Theme.text)
        .preferredColorScheme(.dark)
    }

    private var form: some View {
        Group {
            DialogHeading(title: Text("Nova Branch de workspace"),
                          subtitle: Text("O ns cria a branch em cada Repo e prepara banco, aliases e dependências. Nenhum Serviço é iniciado."))
            VStack(alignment: .leading, spacing: 14) {
                field("Nome da branch") {
                    TextField("", text: $creation.name)
                        .focused($nameFocused)
                        .onSubmit(start)
                        .dialogField(focused: nameFocused)
                        .accessibilityLabel("Nome da branch")
                }
                field("Base") {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 11))
                        Text("master")
                            .font(.system(size: 12.5, design: .monospaced))
                        Spacer(minLength: 0)
                        Text("padrão do ns")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .foregroundStyle(Theme.textSecondary)
                    .padding(.horizontal, 11)
                    .frame(height: 34)
                    .background(Theme.card, in: DialogBox.shape)
                    .overlay(DialogBox.shape.strokeBorder(Theme.border))
                }
                field("Repos") {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible())], spacing: 6) {
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
            .padding(EdgeInsets(top: 14, leading: 20, bottom: 4, trailing: 20))
            DialogFooter {
                Spacer(minLength: 0)
                DialogCancelButton { creation.isPresented = false }
                Button(action: start) { Text("Criar e preparar").pillLabel() }
                    .buttonStyle(.denPrimary)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!creation.canCreate)
            }
        }
        .onAppear { nameFocused = true }
    }

    @ViewBuilder
    private var progress: some View {
        DialogHeading(title: Text("Criando \(Text(creation.name).font(.system(size: 14, weight: .semibold, design: .monospaced)))"),
                      subtitle: Text("Pode fechar esta janela; a criação continua e aparece na barra lateral."))
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(creation.steps) { StepRow(step: $0) }
                }
                if let question = creation.question {
                    QuestionBox(question: question, reply: creation.reply)
                }
                ForEach(creation.missing) { missing in
                    FailureBox(title: "\(missing.repo) não foi incluído.", detail: "A branch foi mantida sem ele.",
                               message: missing.message) {
                        if missing.retrying {
                            ProgressView().controlSize(.small)
                        } else {
                            Button { Task { await creation.retry(missing.repo) } } label: {
                                Text("Repetir \(missing.repo)").pillLabel()
                            }
                                .buttonStyle(.denSecondary)
                        }
                    }
                }
                if let stopped {
                    FailureBox(title: stopped.title, detail: nil,
                               message: [stopped.failure.message, stopped.failure.hint].compactMap(\.self)
                                   .joined(separator: "\n")) {
                        EmptyView()
                    }
                }
            }
            .padding(EdgeInsets(top: 14, leading: 20, bottom: 4, trailing: 20))
            DialogFooter {
                Text(footerNote)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
                Spacer(minLength: 0)
                Button { creation.isPresented = false } label: { Text("Fechar").pillLabel() }
                    .buttonStyle(DenButtonStyle(kind: creation.phase == .finished ? .primary : .secondary))
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

    private var footerNote: String {
        switch creation.phase {
        case .form, .running: "Preparando…"
        case .finished: "Pronto. A Sessão abriu na raiz da branch."
        case .failed, .notPrepared: ""
        }
    }

    private func field(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            content()
        }
    }

}

private struct StepRow: View {
    let step: BranchCreation.Step

    var body: some View {
        HStack(spacing: 10) {
            icon.frame(width: 18, height: 18)
            Text(step.title)
                .font(.system(size: 13))
                .foregroundStyle(step.state == .waiting ? Theme.textTertiary : Theme.textSecondary)
            Spacer(minLength: 4)
            if let detail = step.detail {
                Text(detail)
                    .font(.system(size: 11.5, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(height: 30)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var icon: some View {
        switch step.state {
        case .waiting:
            Circle().strokeBorder(Theme.textFaint, style: StrokeStyle(lineWidth: 1.5, dash: [2.5, 2.5]))
        case .running:
            ProgressView().controlSize(.mini)
        case .done:
            symbol("checkmark", Theme.added, on: Theme.addedFill)
        case .failed:
            symbol("xmark", Theme.removed, on: Theme.removedFill)
        }
    }

    private func symbol(_ name: String, _ color: Color, on fill: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 18, height: 18)
            .background(fill, in: Circle())
    }
}

private struct QuestionBox: View {
    let question: NsQuestion
    var reply: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("O ns pergunta")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textTertiary)
                Text(question.message)
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button { reply(false) } label: { Text("Não").pillLabel() }
                    .buttonStyle(DenButtonStyle(kind: question.default ? .secondary : .primary))
                Button { reply(true) } label: { Text("Sim").pillLabel() }
                    .buttonStyle(DenButtonStyle(kind: question.default ? .primary : .secondary))
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
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 13))
                .foregroundStyle(Theme.removed)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(Text(title).fontWeight(.semibold).foregroundStyle(Theme.removed))\(detail.map { " \($0)" } ?? "")")
                    .font(.system(size: 12.5))
                Text(message)
                    .font(.system(size: 11.5, design: .monospaced))
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
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(border.opacity(0.45)))
    }
}
