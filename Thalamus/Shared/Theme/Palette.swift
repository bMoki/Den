import SwiftUI

extension Color {
    nonisolated init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

nonisolated struct Palette: Sendable {
    struct Surfaces {
        var canvas: Color
        var sidebar: Color
        var panel: Color
        var raised: Color
        var field: Color
        var card: Color
        var bubble: Color
        var hover: Color
        var hoverRaised: Color
        var tip: Color
        var terminal: Color
        var shadow: Color
        var scrim: Color
    }

    struct Borders {
        var border: Color
        var card: Color
        var strong: Color
        var control: Color
    }

    struct Texts {
        var text: Color
        var secondary: Color
        var muted: Color
        var tertiary: Color
        var faint: Color
        var input: Color
        var inlineCode: Color
        var onBadge: Color
    }

    struct Accents {
        var accent: Color
        var soft: Color
        var fill: Color
        var action: Color
        var onAction: Color
    }

    struct Changes {
        var added: Color
        var addedFill: Color
        var removed: Color
        var removedFill: Color
        var modified: Color
        var renamed: Color
        var hunk: Color
        var hunkFill: Color
    }

    struct Alerts {
        var fill: Color
        var border: Color
        var text: Color
    }

    struct SessionStates {
        var awaitingDecision: Color
        var outOfTokens: Color
        var newReply: Color
        var thinking: Color
    }

    struct ServiceStates {
        var stoppedText: Color
        var stoppedMark: Color
        var starting: Color
        var running: Color
        var failed: Color
    }

    struct FileStates {
        var modified: Color
        var added: Color
        var deleted: Color
        var renamed: Color
        var conflicted: Color
    }

    struct ContextLevels {
        var calm: Color
        var warning: Color
        var critical: Color
    }

    struct ContextCategories {
        var messages: Color
        var tools: Color
        var system: Color
        var skills: Color
        var agents: Color
        var memory: Color
        var autocompactBuffer: Color
        var systemPrompt: Color
    }

    struct Checks {
        var passed: Color
        var failed: Color
        var warning: Color
    }

    struct SlashCommands {
        var compact: Color
        var skills: Color
        var mcp: Color
        var mcpConnected: Color
        var mcpUnavailable: Color
    }

    struct Syntax {
        var keyword: Color
        var command: Color
        var string: Color
        var number: Color
        var type: Color
        var comment: Color
        var attribute: Color
    }

    var surfaces: Surfaces
    var borders: Borders
    var texts: Texts
    var accents: Accents
    var changes: Changes
    var alerts: Alerts
    var sessionStates: SessionStates
    var serviceStates: ServiceStates
    var fileStates: FileStates
    var contextLevels: ContextLevels
    var contextCategories: ContextCategories
    var checks: Checks
    var slashCommands: SlashCommands
    var syntax: Syntax
    var terminalANSI: [Color]
}

nonisolated extension Palette {
    static let current = indigo

    static let indigo: Palette = {
        let accent = Color(hex: 0x8B93FF)
        let accentSoft = Color(hex: 0xA8AEFF)
        let added = Color(hex: 0x7FCB92)
        let removed = Color(hex: 0xF08C7E)
        let modified = Color(hex: 0xE0B45F)
        let renamed = Color(hex: 0xC3AEF0)
        let hunk = Color(hex: 0x93AEE8)
        let alertText = Color(hex: 0xEBC46A)
        let textTertiary = Color(hex: 0x7F879A)
        let textFaint = Color(hex: 0x555C6C)
        return Palette(
            surfaces: Surfaces(canvas: Color(hex: 0x0F1115), sidebar: Color(hex: 0x14171D),
                               panel: Color(hex: 0x121419), raised: Color(hex: 0x1A1E26),
                               field: Color(hex: 0x1D212A), card: Color(hex: 0x161920),
                               bubble: Color(hex: 0x232836), hover: Color(hex: 0x222631),
                               hoverRaised: Color(hex: 0x282D39), tip: Color(hex: 0x1E222B),
                               terminal: Color(hex: 0x0A0C0F), shadow: .black, scrim: .black),
            borders: Borders(border: Color(hex: 0x242833), card: Color(hex: 0x272C38),
                             strong: Color(hex: 0x2F3542), control: Color(hex: 0x363C4B)),
            texts: Texts(text: Color(hex: 0xE6E9F0), secondary: Color(hex: 0xB8BFCE),
                         muted: Color(hex: 0x9AA2B4), tertiary: textTertiary, faint: textFaint,
                         input: Color(nsColor: .labelColor), inlineCode: accentSoft,
                         onBadge: .white),
            accents: Accents(accent: accent, soft: accentSoft, fill: Color(hex: 0x1D2035),
                             action: Color(hex: 0x6E78F7), onAction: Color(hex: 0xFFFFFF)),
            changes: Changes(added: added, addedFill: Color(hex: 0x16291C),
                             removed: removed, removedFill: Color(hex: 0x351C18),
                             modified: modified, renamed: renamed,
                             hunk: hunk, hunkFill: Color(hex: 0x1B2233)),
            alerts: Alerts(fill: Color(hex: 0x1F1B12), border: Color(hex: 0x4D3F1F), text: alertText),
            sessionStates: SessionStates(awaitingDecision: alertText, outOfTokens: removed,
                                         newReply: added, thinking: accent),
            serviceStates: ServiceStates(stoppedText: textTertiary, stoppedMark: textFaint,
                                         starting: accent, running: added, failed: removed),
            fileStates: FileStates(modified: modified, added: added, deleted: removed,
                                   renamed: renamed, conflicted: accent),
            contextLevels: ContextLevels(calm: hunk, warning: modified, critical: removed),
            contextCategories: ContextCategories(messages: hunk, tools: Color(hex: 0xE8906F),
                                                 system: added, skills: modified, agents: renamed,
                                                 memory: Color(hex: 0x8FC7C0),
                                                 autocompactBuffer: Color(hex: 0x5E5A52),
                                                 systemPrompt: Color(hex: 0xA8A398)),
            checks: Checks(passed: .green, failed: .red, warning: .orange),
            slashCommands: SlashCommands(compact: .blue, skills: .purple, mcp: .teal,
                                         mcpConnected: .green, mcpUnavailable: .orange),
            syntax: Syntax(keyword: Color(hex: 0xB4A8FF), command: accentSoft,
                           string: Color(hex: 0xB5CE8A), number: Color(hex: 0xF2B482),
                           type: Color(hex: 0x7FD1D9), comment: Color(hex: 0x6B7385),
                           attribute: modified),
            terminalANSI: [
                0x000000, 0xC23621, 0x25BC24, 0xADAD27, 0x492EE1, 0xD338D3, 0x33BBC8, 0xCBCCCD,
                0x818383, 0xFC391F, 0x31E722, 0xEAEC23, 0x5833FF, 0xF935F8, 0x14F0F0, 0xE9EBEB,
            ].map { Color(hex: $0) })
    }()
}
