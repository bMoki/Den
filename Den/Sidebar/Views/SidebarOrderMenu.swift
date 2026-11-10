import SwiftUI

struct SidebarOrderMenu: View {
    @Binding var layout: SidebarLayout

    private var sections: [ThalamusMenuSection] {
        [ThalamusMenuSection(id: "order", items: SidebarOrder.allCases.map { order in
            ThalamusMenuItem(id: order.rawValue, title: order.label, isSelected: layout.order == order) {
                layout.order = order
            }
        })]
    }

    var body: some View {
        ThalamusMenuChip(sections: sections, radius: 6) {
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
