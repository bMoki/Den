import HarnessCore
import SwiftUI

struct AssistantTurn<Content: View>: View {
    let harness: HarnessID
    let showsHeader: Bool
    let moment: Date?
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: Theme.space(.s12)) {
            Group {
                if showsHeader {
                    HarnessBadge(harness: harness, size: .s28)
                } else {
                    Color.clear
                }
            }
            .frame(width: Theme.size(.s28), height: showsHeader ? Theme.size(.s28) : Theme.line(.thin))

            VStack(alignment: .leading, spacing: Theme.space(.s8)) {
                if showsHeader {
                    HStack(spacing: Theme.space(.s6)) {
                        Text(HarnessBadge.name(for: harness))
                            .fontWeight(.medium)
                        if let moment {
                            Text("·")
                            Text(moment, format: .dateTime.hour().minute())
                                .monospacedDigit()
                        }
                    }
                    .font(Theme.font(.small))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(height: Theme.size(.s28), alignment: .center)
                    .padding(.bottom, -Theme.space(.s6))
                }
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
