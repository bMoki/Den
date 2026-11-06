import AppKit
import SwiftUI

enum IndicatorStyle: String, CaseIterable, Identifiable {
    case dots, icons

    static let storageKey = "Den.indicatorStyle"
    static let standard = IndicatorStyle.dots

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dots: "Pontos"
        case .icons: "Ícones"
        }
    }
}

enum TechLogo: String, CaseIterable {
    case quarkus, java, vite, chakra, react, tailwind, bun, typescript, expo

    var title: String {
        switch self {
        case .quarkus: "Quarkus"
        case .java: "Java"
        case .vite: "Vite"
        case .chakra: "Chakra UI"
        case .react: "React"
        case .tailwind: "Tailwind"
        case .bun: "Bun"
        case .typescript: "TypeScript"
        case .expo: "Expo"
        }
    }

    var assetName: String { "logo-\(rawValue)" }
}

enum IndicatorIcon: Hashable, Identifiable {
    case logo(TechLogo)
    case symbol(String)

    private static let logoPrefix = "logo:"

    init?(encoded: String) {
        if encoded.hasPrefix(Self.logoPrefix) {
            guard let logo = TechLogo(rawValue: String(encoded.dropFirst(Self.logoPrefix.count))) else { return nil }
            self = .logo(logo)
        } else if encoded.isEmpty {
            return nil
        } else {
            self = .symbol(encoded)
        }
    }

    var id: String { encoded }

    var encoded: String {
        switch self {
        case .logo(let logo): Self.logoPrefix + logo.rawValue
        case .symbol(let name): name
        }
    }

    var title: String {
        switch self {
        case .logo(let logo): logo.title
        case .symbol(let name): name
        }
    }

    var isAvailable: Bool {
        switch self {
        case .logo: true
        case .symbol(let name): Self.symbolExists(name)
        }
    }

    var image: Image {
        switch self {
        case .logo(let logo): Image(logo.assetName).renderingMode(.template)
        case .symbol(let name): Image(systemName: name)
        }
    }

    static func symbolExists(_ name: String) -> Bool {
        !name.isEmpty && NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
    }

    static var catalog: [IndicatorIcon] {
        var seen = Set<IndicatorIcon>()
        let symbols = IndicatorTarget.all.flatMap(\.suggestions).filter {
            if case .symbol = $0 { seen.insert($0).inserted } else { false }
        }
        return symbols + TechLogo.allCases.map(IndicatorIcon.logo)
    }
}

enum IndicatorTarget: Hashable, Identifiable {
    case service(String)
    case database

    private struct Icons {
        var standard: IndicatorIcon?
        var symbols: [String]
        var logos: [TechLogo]
    }

    private static let serviceIcons: [String: Icons] = [
        "backend": Icons(standard: .logo(.quarkus),
                         symbols: ["server.rack", "curlybraces", "cpu", "cup.and.saucer", "gearshape.2"],
                         logos: [.quarkus, .java]),
        "frontend": Icons(standard: .logo(.vite),
                          symbols: ["macwindow", "desktopcomputer", "globe", "rectangle.3.group", "cursorarrow"],
                          logos: [.vite, .chakra, .react]),
        "manager": Icons(standard: .logo(.tailwind),
                         symbols: ["slider.horizontal.3", "checkmark.shield", "key", "building.2", "person.badge.key"],
                         logos: [.vite, .tailwind, .react]),
        "report-server": Icons(standard: .logo(.bun),
                               symbols: ["doc.text", "chart.bar", "chart.bar.doc.horizontal", "printer", "scroll"],
                               logos: [.bun, .typescript]),
    ]

    private static let databaseIcons = Icons(standard: .symbol("cylinder"), symbols: ["cylinder"], logos: [])

    static var services: [IndicatorTarget] { NsStatus.Branch.serviceIDs.map(IndicatorTarget.service) }
    static var all: [IndicatorTarget] { services + [.database] }

    var id: String {
        switch self {
        case .service(let id): id
        case .database: "banco"
        }
    }

    var storageKey: String { "Den.indicator.\(id)" }

    private var icons: Icons? {
        switch self {
        case .service(let id): Self.serviceIcons[id]
        case .database: Self.databaseIcons
        }
    }

    var standardIcon: IndicatorIcon? { icons?.standard }

    var suggestions: [IndicatorIcon] {
        guard let icons else { return [] }
        return icons.logos.map(IndicatorIcon.logo) + icons.symbols.map(IndicatorIcon.symbol)
    }

    func icon(encoded: String?) -> IndicatorIcon? {
        guard let encoded else { return standardIcon }
        return IndicatorIcon(encoded: encoded).flatMap { $0.isAvailable ? $0 : nil }
    }

    func encoded(for icon: IndicatorIcon) -> String? {
        icon == standardIcon ? nil : icon.encoded
    }
}

enum IndicatorPreferences {
    static func restoreStandards(in defaults: UserDefaults) {
        defaults.removeObject(forKey: IndicatorStyle.storageKey)
        for target in IndicatorTarget.all {
            defaults.removeObject(forKey: target.storageKey)
        }
    }
}

struct ServiceIndicator: View {
    let target: IndicatorTarget
    let state: ServiceState
    let iconSize: CGFloat

    @AppStorage(IndicatorStyle.storageKey) private var style: IndicatorStyle?
    @AppStorage private var encodedIcon: String?

    init(_ target: IndicatorTarget, state: ServiceState, iconSize: CGFloat = 12) {
        self.target = target
        self.state = state
        self.iconSize = iconSize
        _encodedIcon = AppStorage(target.storageKey)
    }

    var body: some View {
        if style == .icons, let icon = target.icon(encoded: encodedIcon) {
            IndicatorGlyph(icon: icon, color: Self.color(state), size: iconSize)
                .pulsing(state == .iniciando)
                .accessibilityHidden(true)
        } else {
            ServiceDot(state: state, isDatabase: target == .database)
        }
    }

    static func color(_ state: ServiceState) -> Color {
        state == .parado ? Theme.textFaint : ServiceDot.color(state)
    }
}

struct IndicatorGlyph: View {
    let icon: IndicatorIcon
    let color: Color
    var size: CGFloat = 12

    var body: some View {
        icon.image
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(color)
    }
}
