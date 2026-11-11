import SwiftUI
import HarnessCore

struct PermissionCard: View {
    let request: PermissionRequest
    let harnessName: String
    var resolve: (PermissionOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space(.s10)) {
            HStack(spacing: Theme.space(.s8)) {
                Theme.image(.modeBypass)
                    .font(Theme.font(.large, weight: .medium))
                Text("\(harnessName) pede permissão para usar \(request.displayName ?? request.toolName)")
                    .font(Theme.font(.body, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Theme.alertText)

            if let detail = detail(of: request) {
                Text(detail)
                    .font(Theme.font(.smallPlus, design: .monospaced))
                    .foregroundStyle(Theme.text)
                    .textSelection(.enabled)
                    .lineLimit(4)
                    .padding(.horizontal, Theme.space(.s12))
                    .padding(.vertical, Theme.space(.s10))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.terminal, in: RoundedRectangle(cornerRadius: Theme.radius(.r8)))
                    .overlay(RoundedRectangle(cornerRadius: Theme.radius(.r8))
                        .strokeBorder(Theme.border, lineWidth: Theme.line(.thin)))
            }

            HStack(spacing: Theme.space(.s8)) {
                ForEach(request.options, id: \.id) { option in
                    let button = Button {
                        resolve(option)
                    } label: {
                        Text(option.label).pillLabel()
                    }

                    if option.kind == .allowOnce {
                        button
                            .buttonStyle(.thalamusPrimary)
                            .keyboardShortcut(.defaultAction)
                    } else {
                        button.buttonStyle(.thalamusSecondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(Theme.space(.s14))
        .background(Theme.alertFill, in: RoundedRectangle(cornerRadius: Theme.radius(.r12), style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius(.r12), style: .continuous)
            .strokeBorder(Theme.alertBorder, lineWidth: Theme.line(.thin)))
    }

    private func detail(of request: PermissionRequest) -> String? {
        request.input["command"]?.stringValue
        ?? request.input["file_path"]?.stringValue
        ?? request.description
    }
}
