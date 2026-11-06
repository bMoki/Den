import SwiftUI

struct PullRequestChip: View {
    let pullRequest: PullRequest

    var body: some View {
        let tone = PullRequestStatus.tone(pullRequest)
        HStack(spacing: 3) {
            Image(systemName: tone.symbol)
                .font(.system(size: 8.5, weight: .bold))
            Text(PullRequestStatus.number(pullRequest))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(tone.color)
        .padding(.horizontal, 5)
        .frame(height: 17)
        .background(tone.fill, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}
