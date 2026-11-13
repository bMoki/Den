import SwiftUI

struct PullRequestChip: View {
    let pullRequest: PullRequest

    var body: some View {
        let tone = PullRequestStatus.tone(pullRequest)
        HStack(spacing: Theme.space(.s3)) {
            Theme.image(tone.symbol, size: .tinyPlus, weight: .bold)
            Text(PullRequestStatus.number(pullRequest))
                .font(Theme.font(.caption, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(tone.color)
        .padding(.horizontal, Theme.space(.s5))
        .frame(height: Theme.size(.s17))
        .background(tone.fill, in: RoundedRectangle(cornerRadius: Theme.radius(.r5), style: .continuous))
    }
}
