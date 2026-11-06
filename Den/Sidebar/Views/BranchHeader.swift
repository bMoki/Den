import SwiftUI

struct BranchHeader: View {
    let name: String
    let branch: NsStatus.Branch?
    let activity: NsWorkspace.Activity?
    var problem: String?
    var pullRequests: [PullRequest] = []
    let sessionCount: Int
    let isOpen: Bool
    var toggle: () -> Void
    var newSession: () -> Void
    var start: () -> Void
    var stop: () -> Void
    var update: () -> Void
    var remove: () -> Void

    @State private var hovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                DisclosureChevron(isOpen: isOpen)
                Text(name)
                    .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 4)
                if hovering || activity != nil {
                    actions
                } else if sessionCount > 0 {
                    SessionCountLabel(count: sessionCount)
                }
            }
            .frame(height: 20)
            if let branch, !branch.services.isEmpty || !pullRequests.isEmpty {
                HStack(spacing: 4) {
                    if !branch.services.isEmpty {
                        ForEach(branch.services) { ServiceIndicator(.service($0.id), state: $0.state) }
                        ServiceIndicator(.database, state: branch.database)
                            .padding(.leading, 2)
                    }
                    ForEach(pullRequests, id: \.url) { PullRequestChip(pullRequest: $0) }
                        .padding(.leading, 4)
                    if let activity {
                        Text(activity.label)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                            .padding(.leading, 4)
                    }
                }
                .padding(.leading, 20)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(stateSummary(branch))
            }
            if let problem, activity == nil {
                Text(problem)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.removed)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 20)
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .sidebarHeaderRow(hovering: $hovering, isOpen: isOpen, toggle: toggle)
        .denContextMenu([
            DenMenuSection(id: "services", items: [
                DenMenuItem(id: "start", title: BranchActionTitle.start, isEnabled: activity == nil, action: start),
                DenMenuItem(id: "stop", title: BranchActionTitle.stop, isEnabled: activity == nil, action: stop),
            ]),
            DenMenuSection(id: "branch", items: [
                DenMenuItem(id: "update", title: BranchActionTitle.update, isEnabled: activity == nil, action: update),
                DenMenuItem(id: "new-session", title: "Nova sessão aqui", action: newSession),
            ]),
            DenMenuSection(id: "remove", items: [
                DenMenuItem(id: "remove", title: BranchActionTitle.remove, isEnabled: activity == nil,
                            isDestructive: true, action: remove),
            ]),
        ])
        .accessibilityElement(children: .contain)
        .accessibilityLabel(name)
        .accessibilityValue(isOpen ? "aberta" : "fechada")
    }

    private func stateSummary(_ branch: NsStatus.Branch) -> String {
        let parts = (branch.services.isEmpty ? [] : [branch.stateSummary])
            + pullRequests.map { "PR \(PullRequestStatus.number($0)) \(PullRequestStatus.label($0))" }
        return parts.joined(separator: ", ")
    }

    private var actions: some View {
        HStack(spacing: 2) {
            if activity != nil {
                ProgressView()
                    .controlSize(.mini)
                    .frame(width: 24, height: 20)
            } else {
                action("play.fill", title: BranchActionTitle.start, perform: start)
                action("stop.fill", title: BranchActionTitle.stop, perform: stop)
            }
        }
    }

    private func action(_ symbol: String, title: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Image(systemName: symbol)
                .font(.system(size: 9.5))
                .foregroundStyle(Theme.textMuted)
                .iconLabel(size: 22)
        }
        .buttonStyle(.denGhost(radius: 6))
        .help(title)
        .accessibilityLabel(title)
    }
}
