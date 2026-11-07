import SwiftUI

struct SidebarOrderMenu: View {
    @Binding var layout: SidebarLayout

    private var sections: [DenMenuSection] {
        [DenMenuSection(id: "order", items: SidebarOrder.allCases.map { order in
            DenMenuItem(id: order.rawValue, title: order.label, isSelected: layout.order == order) {
                layout.order = order
            }
        })]
    }

    var body: some View {
        DenMenuChip(sections: sections, radius: 6) {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .iconLabel(size: 22)
        }
        .help("Ordenar branches")
        .accessibilityLabel("Ordenar branches")
        .accessibilityValue(layout.order.label)
    }
}
