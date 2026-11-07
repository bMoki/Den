import SwiftUI

struct BranchHeader: View {
    let name: String
    let branch: NsStatus.Branch?
    let activity: NsWorkspace.Activity?
    var problem: String?
    var pullRequests: [PullRequest] = []
    let sessions: SessionTally
    let isOpen: Bool
    var toggle: () -> Void
    var newSession: () -> Void
    var start: () -> Void
    var stop: () -> Void
    var update: () -> Void
    var remove: () -> Void
    var setNickname: (String) -> Void
    let isFavorite: Bool
    var toggleFavorite: () -> Void

    @State private var hovering = false
    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                DisclosureChevron(isOpen: isOpen)
                title
                Spacer(minLength: 4)
                if hovering || activity != nil {
                    actions
                }
                SessionTallyLabel(sessions: sessions)
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
                DenMenuItem(id: "nickname", title: BranchActionTitle.nickname) { isEditing = true },
                FavoriteTitle.item(isFavorite: isFavorite, toggle: toggleFavorite),
            ]),
            DenMenuSection(id: "remove", items: [
                DenMenuItem(id: "remove", title: BranchActionTitle.remove, isEnabled: activity == nil,
                            isDestructive: true, action: remove),
            ]),
        ])
        .accessibilityElement(children: .contain)
        .accessibilityLabel(branch?.nickname.map { "\($0), \(name)" } ?? name)
        .accessibilityValue(isOpen ? "aberta" : "fechada")
    }

    @ViewBuilder
    private var title: some View {
        if isEditing {
            InlineRenameField(initial: branch?.nickname ?? "", placeholder: name, limit: BranchNickname.maxLength,
                              commit: setNickname) { isEditing = false }
                .font(.system(size: 12.5, weight: .medium))
                .padding(.horizontal, 5)
                .frame(height: 20)
                .background(Theme.field, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Theme.accent))
        } else if let nickname = branch?.nickname {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(nickname)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(name)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .fixedSize()
            }
        } else {
            Text(name)
                .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
        }
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
