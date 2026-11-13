import SwiftUI

struct BranchHeader: View {
    let name: String
    let branch: NsStatus.Branch?
    let activity: NsWorkspace.Activity?
    var problem: String?
    var pullRequests: [PullRequest] = []
    let sessions: SessionTally
    let isSelected: Bool
    var open: () -> Void
    var newSession: () -> Void
    var start: () -> Void
    var stop: () -> Void
    var update: () -> Void
    let addableRepos: [BranchCreation.Repo]
    var addRepo: (BranchCreation.Repo) -> Void
    var remove: () -> Void
    var setNickname: (String) -> Void
    let isFavorite: Bool
    var toggleFavorite: () -> Void

    @State private var hovering = false
    @State private var isEditing = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.space(.s4)) {
            HStack(spacing: Theme.space(.s8)) {
                title
                Spacer(minLength: Theme.space(.s4))
                if hovering || activity != nil {
                    actions
                }
                SessionTallyLabel(sessions: sessions)
            }
            .frame(height: Theme.size(.s20))
            if let branch, !branch.services.isEmpty || !pullRequests.isEmpty {
                HStack(spacing: Theme.space(.s4)) {
                    if !branch.services.isEmpty {
                        ForEach(branch.services) { ServiceIndicator(.service($0.id), state: $0.state) }
                        ServiceIndicator(.database, state: branch.database)
                            .padding(.leading, Theme.space(.s2))
                    }
                    ForEach(pullRequests, id: \.url) { PullRequestChip(pullRequest: $0) }
                        .padding(.leading, Theme.space(.s4))
                    if let activity {
                        Text(activity.label)
                            .font(Theme.font(.caption))
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                            .padding(.leading, Theme.space(.s4))
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(stateSummary(branch))
            }
            if let problem, activity == nil {
                Text(problem)
                    .font(Theme.font(.caption))
                    .foregroundStyle(Theme.removed)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.leading, Theme.space(.s10))
        .padding(.trailing, Theme.space(.s6))
        .padding(.vertical, Theme.space(.s6))
        .sidebarHeaderRow(hovering: $hovering, isSelected: isSelected, open: open)
        .thalamusContextMenu(menu)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(branch?.nickname.map { "\($0), \(name)" } ?? name)
    }

    private var menu: [ThalamusMenuSection] {
        let idle = activity == nil
        let adding = addableRepos.isEmpty ? [] : [
            ThalamusMenuItem(id: "add-repo", title: BranchActionTitle.addRepo, isEnabled: idle, children: [
                ThalamusMenuSection(items: addableRepos.map { repo in
                    ThalamusMenuItem(id: repo.rawValue, title: repo.rawValue) { addRepo(repo) }
                }),
            ]),
        ]
        return [
            ThalamusMenuSection(id: "services", items: [
                ThalamusMenuItem(id: "start", title: BranchActionTitle.start, isEnabled: idle, action: start),
                ThalamusMenuItem(id: "stop", title: BranchActionTitle.stop, isEnabled: idle, action: stop),
            ]),
            ThalamusMenuSection(id: "branch", items: [
                ThalamusMenuItem(id: "update", title: BranchActionTitle.update, isEnabled: idle, action: update),
            ] + adding + [
                ThalamusMenuItem(id: "new-session", title: "Nova sessão aqui", action: newSession),
                ThalamusMenuItem(id: "nickname", title: BranchActionTitle.nickname) { isEditing = true },
                FavoriteTitle.item(isFavorite: isFavorite, toggle: toggleFavorite),
            ]),
            ThalamusMenuSection(id: "remove", items: [
                ThalamusMenuItem(id: "remove", title: BranchActionTitle.remove, isEnabled: idle,
                            isDestructive: true, action: remove),
            ]),
        ]
    }

    @ViewBuilder
    private var title: some View {
        if isEditing {
            InlineRenameField(initial: branch?.nickname ?? "", placeholder: name, limit: BranchNickname.maxLength,
                              commit: setNickname) { isEditing = false }
                .font(Theme.font(.smallPlus, weight: .medium))
                .padding(.horizontal, Theme.space(.s5))
                .frame(height: Theme.size(.s20))
                .background(Theme.field, in: RoundedRectangle(cornerRadius: Theme.radius(.r4), style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.radius(.r4), style: .continuous).strokeBorder(Theme.accent))
        } else if let nickname = branch?.nickname {
            HStack(alignment: .firstTextBaseline, spacing: Theme.space(.s6)) {
                Text(nickname)
                    .font(Theme.font(.smallPlus, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(name)
                    .font(Theme.font(.caption, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .fixedSize()
            }
        } else {
            Text(name)
                .font(Theme.font(.smallPlus, weight: .medium, design: .monospaced))
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
        HStack(spacing: Theme.space(.s2)) {
            if activity != nil {
                ProgressView()
                    .controlSize(.mini)
                    .frame(width: Theme.size(.s24), height: Theme.size(.s20))
            } else {
                action(.start, title: BranchActionTitle.start, perform: start)
                action(.stop, title: BranchActionTitle.stop, perform: stop)
            }
        }
    }

    private func action(_ symbol: Icon, title: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Theme.image(symbol, size: .miniPlus)
                .foregroundStyle(Theme.textMuted)
                .iconLabel(size: .s22)
        }
        .buttonStyle(.thalamusGhost(radius: .r6))
        .tip(title)
        .accessibilityLabel(title)
    }
}
