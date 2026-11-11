import SwiftUI
import HarnessCore

struct HarnessSwitcher: View {
    let chat: ChatModel

    private var sections: [ThalamusMenuSection] {
        [ThalamusMenuSection(header: "Harness desta sessão",
                        items: chat.availableHarnesses.map { candidate in
            ThalamusMenuItem(id: candidate.rawValue,
                        title: HarnessBadge.name(for: candidate),
                        icon: .image(HarnessBadge.menuIcon(for: candidate)),
                        isSelected: candidate == chat.harness,
                        isEnabled: candidate != chat.harness) {
                Task { await chat.switchHarness(to: candidate) }
            }
        })]
    }

    var body: some View {
        ThalamusMenuChip(sections: sections, bordered: true, radius: .r10) {
            HStack(spacing: Theme.space(.s8)) {
                HarnessBadge(harness: chat.harness, size: .s20)
                Text(chat.harnessName)
                    .font(Theme.font(.body, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Spacer(minLength: Theme.space(.s4))
                Chevron()
            }
            .padding(.leading, Theme.space(.s7))
            .padding(.trailing, Theme.space(.s10))
            .frame(minWidth: 150)
            .frame(height: Theme.size(.s32))
            .contentShape(Rectangle())
        }
        .disabled(!chat.canSwitchHarness)
        .help(chat.isBusy
              ? "Espere o turno terminar para trocar de harness"
              : "Trocar de harness levando a conversa junto")
    }

}
