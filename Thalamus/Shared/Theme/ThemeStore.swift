import Foundation
import Observation
import Synchronization

nonisolated final class ThemeStore: Observable, Sendable {
    static let shared = ThemeStore()

    static let styleKey = PreferenceKey.named("style")
    static let paletteKey = PreferenceKey.named("palette")

    private final class Pair: Sendable {
        let style: Style
        let palette: Palette

        init(style: Style, palette: Palette) {
            self.style = style
            self.palette = palette
        }
    }

    private let registrar = ObservationRegistrar()
    private let current = Mutex(Pair(style: .padrao, palette: Palette.indigo))
    private let styles: [Style]
    private let palettes: [Palette]

    init(styles: [Style] = Style.all, palettes: [Palette] = Palette.all) {
        self.styles = styles
        self.palettes = palettes
    }

    var style: Style { pair.style }
    var palette: Palette { pair.palette }

    private var pair: Pair {
        registrar.access(self, keyPath: \.pair)
        return current.withLock { $0 }
    }

    func use(style: Style? = nil, palette: Palette? = nil) {
        registrar.withMutation(of: self, keyPath: \.pair) {
            current.withLock { pair in
                pair = Pair(style: style ?? pair.style, palette: palette ?? pair.palette)
            }
        }
    }

    func restore(from defaults: UserDefaults) {
        let style = defaults.string(forKey: Self.styleKey)
        let palette = defaults.string(forKey: Self.paletteKey)
        use(style: styles.first { $0.id == style } ?? .padrao,
            palette: palettes.first { $0.id == palette } ?? Palette.indigo)
    }

    func choose(_ style: Style, in defaults: UserDefaults) {
        defaults.set(style.id, forKey: Self.styleKey)
        use(style: style)
    }

    func choose(_ palette: Palette, in defaults: UserDefaults) {
        defaults.set(palette.id, forKey: Self.paletteKey)
        use(palette: palette)
    }
}

extension Theme {
    @MainActor
    static func follow<Owner: AnyObject>(_ owner: Owner, _ apply: @escaping @MainActor (Owner) -> Void) {
        let followed = Followed(owner)
        withObservationTracking { apply(owner) } onChange: {
            Task { @MainActor in
                if let owner = followed.owner { follow(owner, apply) }
            }
        }
    }
}

@MainActor
private final class Followed<Owner: AnyObject> {
    weak var owner: Owner?

    init(_ owner: Owner) {
        self.owner = owner
    }
}
