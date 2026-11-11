import SwiftUI

struct FileNameSheet: View {
    let request: FileNameRequest
    let root: URL
    var cancel: () -> Void
    var submit: (_ name: String) throws -> Void

    @State private var name: String
    @State private var failure: String?

    init(request: FileNameRequest, root: URL, cancel: @escaping () -> Void, submit: @escaping (_ name: String) throws -> Void) {
        self.request = request
        self.root = root
        self.cancel = cancel
        self.submit = submit
        _name = State(initialValue: request.initialName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DialogHeading(title: Text(request.title),
                          subtitle: Text("Em \(Text(place).font(Theme.font(.smallPlus, design: .monospaced)))."))
            VStack(alignment: .leading, spacing: Theme.space(.s8)) {
                DialogNameField(name: $name, accessibilityLabel: "Nome", submit: confirm)
                if let note {
                    Text(note)
                        .font(Theme.font(.small))
                        .foregroundStyle(Theme.alertText)
                }
            }
            .dialogBody()
            DialogFooter {
                Spacer(minLength: 0)
                DialogCancelButton(action: cancel)
                Button(action: confirm) { Text(request.title).pillLabel() }
                    .buttonStyle(.thalamusPrimary)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .frame(width: 420)
        .background(Theme.raised)
        .foregroundStyle(Theme.text)
        .onChange(of: name) { failure = nil }
    }

    private var place: String {
        let folder = request.folder.path
        guard folder == root.path || folder.hasPrefix(root.path + "/") else { return folder }
        return root.lastPathComponent + folder.dropFirst(root.path.count)
    }

    private var problem: FileTree.Problem? {
        FileTree.nameProblem(name, in: request.folder, except: request.current)
    }

    private var isValid: Bool { problem == nil && name != request.initialName }

    private var note: String? {
        failure ?? (problem == .emptyName ? nil : problem?.errorDescription)
    }

    private func confirm() {
        guard isValid else { return }
        do {
            try submit(name)
        } catch {
            failure = error.localizedDescription
        }
    }
}
