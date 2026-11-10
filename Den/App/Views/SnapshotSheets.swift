import SwiftUI

struct TakeSnapshotSheet: View {
    let branch: String
    let taken: Set<String>
    var cancel: () -> Void
    var take: (_ name: String, _ replacing: Bool) -> Void

    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DialogHeading(title: Text("Tirar snapshot"),
                          subtitle: Text("Guarda o estado atual do banco de \(Text(branch).font(.system(size: 12.5, design: .monospaced)))."))
            VStack(alignment: .leading, spacing: 8) {
                DialogNameField(name: $name, accessibilityLabel: "Nome do snapshot", submit: submit)
                Text(note)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(problem == nil ? Theme.textTertiary : Theme.alertText)
                if replacing {
                    DialogWarning(title: "Já existe um Snapshot com esse nome.",
                                  detail: "Substituir apaga o Snapshot anterior de \(branch).")
                }
            }
            .padding(EdgeInsets(top: 14, leading: 20, bottom: 4, trailing: 20))
            DialogFooter {
                Spacer(minLength: 0)
                DialogCancelButton(action: cancel)
                Button(action: submit) { Text(replacing ? "Substituir" : "Tirar snapshot").pillLabel() }
                    .buttonStyle(.thalamusPrimary)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .frame(width: 460)
        .background(Theme.raised)
        .foregroundStyle(Theme.text)
        .preferredColorScheme(.dark)
    }

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }

    private var problem: String? {
        if trimmed.contains(":") || trimmed.contains("/") { return "O nome não pode ter ':' nem '/'." }
        if trimmed == "latest" { return "'latest' é reservado para o snapshot mais recente." }
        return nil
    }

    private var isValid: Bool { !trimmed.isEmpty && problem == nil }

    private var replacing: Bool { isValid && taken.contains { $0.lowercased() == trimmed.lowercased() } }

    private var note: String {
        problem ?? "Referência: \(branch):\(trimmed.isEmpty ? "nome" : trimmed)"
    }

    private func submit() {
        if isValid { take(trimmed, replacing) }
    }
}

struct RestoreSnapshotSheet: View {
    let branch: String
    let sources: [NsClient.SnapshotGroup]
    let running: [String]
    var problem: String?
    var cancel: () -> Void
    var restore: (_ ref: String) -> Void

    @State private var selected: String?

    init(branch: String, sources: [NsClient.SnapshotGroup], running: [String], problem: String?, selected: String?,
         cancel: @escaping () -> Void, restore: @escaping (_ ref: String) -> Void) {
        self.branch = branch
        self.sources = sources
        self.running = running
        self.problem = problem
        self.cancel = cancel
        self.restore = restore
        _selected = State(initialValue: selected)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DialogHeading(title: Text("Restaurar banco"),
                          subtitle: Text("Escolha um Snapshot. Pode ser de outra branch."))
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if sources.isEmpty {
                        Text(problem ?? "Nenhum Snapshot encontrado.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.textTertiary)
                            .frame(maxWidth: .infinity, minHeight: 60)
                    }
                    ForEach(sources, id: \.branch) { group in
                        if group.branch == firstOrphan {
                            Text("Órfãos")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                                .padding(.top, 4)
                                .accessibilityAddTraits(.isHeader)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            groupTitle(group)
                            ForEach(group.snapshots) { snapshot in
                                SnapshotChoice(snapshot: snapshot, isSelected: selected == snapshot.ref) {
                                    selected = snapshot.ref
                                }
                            }
                        }
                    }
                }
                .padding(EdgeInsets(top: 14, leading: 20, bottom: 4, trailing: 20))
            }
            .frame(maxHeight: 300)
            .fixedSize(horizontal: false, vertical: true)
            if let selected {
                VStack(alignment: .leading, spacing: 10) {
                    confirmation(selected)
                    if !running.isEmpty {
                        DialogWarning(title: "\(runningSummary) (\(running.joined(separator: ", "))).",
                                      detail: "O Thalamus não vai pará-los nem reiniciá-los; eles podem precisar de reinício depois.")
                    }
                }
                .padding(EdgeInsets(top: 12, leading: 20, bottom: 4, trailing: 20))
            }
            DialogFooter {
                Spacer(minLength: 0)
                DialogCancelButton(action: cancel)
                Button { if let selected { restore(selected) } } label: {
                    Text(selected.map { "Restaurar \($0)" } ?? "Restaurar").pillLabel()
                }
                .buttonStyle(.thalamusPrimary)
                .disabled(selected == nil)
            }
        }
        .frame(width: 560)
        .background(Theme.raised)
        .foregroundStyle(Theme.text)
        .preferredColorScheme(.dark)
    }

    private var runningSummary: String {
        running.count == 1 ? "1 Serviço está Rodando" : "\(running.count) Serviços estão Rodando"
    }

    private var firstOrphan: String? {
        sources.first(where: \.orphan)?.branch
    }

    private func groupTitle(_ source: NsClient.SnapshotGroup) -> some View {
        HStack(spacing: 5) {
            Text(source.branch).font(.system(size: 11.5, weight: .semibold, design: .monospaced))
            if source.orphan {
                Text("· branch removida").font(.system(size: 11.5))
            } else if source.branch == branch {
                Text("· esta branch").font(.system(size: 11.5))
            }
        }
        .foregroundStyle(Theme.textTertiary)
        .padding(.horizontal, 2)
        .padding(.bottom, 2)
    }

    private func confirmation(_ ref: String) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
            GridRow {
                Text("Snapshot").foregroundStyle(Theme.textTertiary)
                Text(ref).font(.system(size: 12.5, weight: .medium, design: .monospaced))
            }
            GridRow {
                Text("Restaura em").foregroundStyle(Theme.textTertiary)
                Text(branch).font(.system(size: 12.5, weight: .medium, design: .monospaced))
            }
        }
        .font(.system(size: 12.5))
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.border))
        .accessibilityElement(children: .combine)
    }
}

private struct SnapshotChoice: View {
    let snapshot: NsClient.Snapshot
    let isSelected: Bool
    var choose: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: choose) {
            HStack(spacing: 9) {
                Circle()
                    .strokeBorder(isSelected ? Theme.action : Theme.borderControl, lineWidth: isSelected ? 4.5 : 1.5)
                    .frame(width: 14, height: 14)
                Text(snapshot.name)
                    .font(.system(size: 12.5, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                if let age = snapshot.age {
                    Text(age)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .background(isSelected ? Theme.hoverRaised : hovering ? Theme.hover : .clear, in: DialogBox.shape)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(snapshot.ref)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}
