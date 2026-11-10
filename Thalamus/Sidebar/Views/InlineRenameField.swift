import SwiftUI

struct InlineRenameField: View {
    let initial: String
    var placeholder = ""
    var limit: Int?
    var commit: (String) -> Void
    var done: () -> Void

    @State private var draft = ""
    @State private var finished = false
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $draft)
            .textFieldStyle(.plain)
            .focused($focused)
            .limiting($draft, to: limit)
            .onAppear {
                draft = initial
                DispatchQueue.main.async { focused = true }
            }
            .onSubmit { finish(committing: true) }
            .onExitCommand { finish(committing: false) }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { finish(committing: true) }
            }
    }

    private func finish(committing: Bool) {
        guard !finished else { return }
        finished = true
        if committing { commit(draft) }
        done()
    }
}

extension View {
    func limiting(_ text: Binding<String>, to limit: Int?) -> some View {
        onChange(of: text.wrappedValue) { _, value in
            if let limit, value.count > limit { text.wrappedValue = String(value.prefix(limit)) }
        }
    }
}
