import SwiftUI
import HarnessCore

enum SlashGroup: String, Identifiable {
    case skills, mcp

    var id: String { rawValue }

    var title: String {
        switch self {
        case .skills: "Habilidades"
        case .mcp: "MCP"
        }
    }

    var icon: Icon {
        switch self {
        case .skills: .skills
        case .mcp: .mcpServer
        }
    }

    var tint: Color {
        switch self {
        case .skills: Theme.palette.slashCommands.skills
        case .mcp: Theme.palette.slashCommands.mcp
        }
    }
}

struct SlashCommand: Identifiable {
    enum Kind {
        case compact
        case group(SlashGroup, count: Int)
        case skill
        case mcpPrompt(server: String)
        case mcpServer(status: CommandCatalog.ServerStatus)
    }

    let id: String
    let title: String
    let detail: String
    let kind: Kind

    var command: String? {
        switch kind {
        case .compact: SlashCatalog.compactCommand
        case .skill, .mcpPrompt: "/" + id
        case .group, .mcpServer: nil
        }
    }

    var group: SlashGroup? {
        if case .group(let group, _) = kind { return group }
        return nil
    }

    var icon: Icon {
        switch kind {
        case .compact: .compact
        case .group(let group, _): group.icon
        case .skill: .skills
        case .mcpPrompt: .mcpPrompt
        case .mcpServer(let status): status == .connected ? .mcpServer : .warning
        }
    }

    var tint: Color {
        switch kind {
        case .compact: Theme.palette.slashCommands.compact
        case .group(let group, _): group.tint
        case .skill: Theme.palette.slashCommands.skills
        case .mcpPrompt: Theme.palette.slashCommands.mcp
        case .mcpServer(let status):
            status == .connected ? Theme.palette.slashCommands.mcpConnected : Theme.palette.slashCommands.mcpUnavailable
        }
    }
}
