import SwiftUI
import HarnessCore

struct KnobBadge: View {
    let knob: HarnessKnob
    let chat: ChatModel
    var compact = false

    static let modeLooks: [String: (symbol: Icon, color: Color)] = [
        "auto": (.modeAuto, Theme.modified),
        "plan": (.modePlan, Theme.hunk),
        "acceptEdits": (.modeAcceptEdits, Theme.renamed),
        "manual": (.modeManual, Theme.textSecondary),
        "dontAsk": (.modeAuto, Theme.accent),
        "bypassPermissions": (.modeBypass, Theme.removed),
        "build": (.agentBuild, Theme.added),
    ]

    static func sections(for knob: HarnessKnob,
                         choose: @escaping (String) -> Void) -> [ThalamusMenuSection] {
        knob.groupedOptions.enumerated().map { index, bucket in
            ThalamusMenuSection(
                id: bucket.group ?? "bucket-\(index)",
                header: bucket.group,
                items: bucket.options.map { option in
                    let look = knob.category == .mode ? modeLooks[option.value] : nil
                    let current = option.value == knob.currentValue
                    return ThalamusMenuItem(
                        id: option.value,
                        title: option.label,
                        icon: look.map { ThalamusMenuIcon.symbol($0.symbol, $0.color) },
                        isSelected: current
                    ) {
                        guard !current else { return }
                        choose(option.value)
                    }
                }
            )
        }
    }

    var body: some View {
        let sections = Self.sections(for: knob) { value in
            Task { await chat.choose(knob: knob.id, value: value) }
        }
        return ThalamusMenuChip(sections: sections, bordered: knob.category == .mode) {
            label
        }
        .tip("\(knob.name): \(knob.label(for: knob.currentValue) ?? "—")")
        .accessibilityLabel("\(knob.name): \(knob.label(for: knob.currentValue) ?? "—")")
    }

    private var label: some View {
        let current = knob.currentValue
        let look = knob.category == .mode ? Self.modeLooks[current ?? ""] : nil
        return HStack(spacing: Theme.space(.s6)) {
            if let look {
                Theme.image(look.symbol, size: .caption, weight: .medium)
                    .foregroundStyle(look.color)
            }
            if !compact || knob.category == .model || (look == nil && knob.category == .mode) {
                Text(knob.label(for: current) ?? knob.name)
                    .foregroundStyle(knob.category == .model ? Theme.text : Theme.textSecondary)
                    .fontWeight(knob.category == .model ? .medium : .regular)
                    .lineLimit(1)
            }
            Chevron(size: .tiny)
        }
        .chipLabel()
    }
}
