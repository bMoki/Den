import SwiftUI

struct DialogHeading: View {
    let title: Text
    let subtitle: Text

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            title.font(.system(size: 15, weight: .semibold))
            subtitle
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(EdgeInsets(top: 18, leading: 20, bottom: 4, trailing: 20))
    }
}

struct DialogFooter<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 8) {
            content()
        }
        .padding(EdgeInsets(top: 14, leading: 20, bottom: 18, trailing: 20))
    }
}
