nonisolated enum Icon: String, CaseIterable, Sendable {
    case next = "chevron.right"
    case back = "chevron.left"
    case expanded = "chevron.down"
    case picker = "chevron.up.chevron.down"
    case toggleSidebar = "sidebar.left"
    case toggleInspector = "sidebar.right"
    case toggleTerminals = "rectangle.bottomthird.inset.filled"
    case jumpToEnd = "arrow.down"
    case send = "arrow.up"
    case submit = "arrow.right"
    case reply = "arrow.turn.down.right"
    case openInBrowser = "arrow.up.right"
    case openInApp = "arrow.up.forward.app"
    case sortOrder = "arrow.up.arrow.down"
    case search = "magnifyingglass"
    case escape

    case add = "plus"
    case close = "xmark"
    case clearSearch = "xmark.circle.fill"
    case newSession = "square.and.pencil"
    case restart = "arrow.clockwise"
    case updateBranch = "arrow.down.to.line"
    case start = "play.fill"
    case stop = "stop.fill"
    case terminal
    case trash
    case copy = "doc.on.doc"
    case newFile = "doc.badge.plus"
    case newFolder = "folder.badge.plus"
    case move = "arrow.right.doc.on.clipboard"
    case mention = "at"
    case attach = "paperclip"
    case show = "eye"
    case hide = "eye.slash"
    case archive = "archivebox"

    case branch = "arrow.triangle.branch"
    case pullRequest = "arrow.triangle.pull"
    case merged = "arrow.triangle.merge"
    case changesRequested = "arrow.uturn.backward"
    case diff = "plus.forwardslash.minus"
    case clean = "checkmark.circle"
    case notARepository = "folder.badge.questionmark"

    case file = "doc"
    case image = "photo"
    case folder
    case folderWithSessions = "folder.fill"
    case attachedFile = "doc.fill"
    case attachment = "doc.plaintext"
    case list = "list.bullet"
    case session = "bubble.left"

    case thinking = "brain"
    case tool = "wrench.and.screwdriver"
    case read = "doc.text"
    case edit = "pencil"
    case write = "plus.square"
    case fetch = "globe"
    case summary = "text.quote"
    case compact = "arrow.down.right.and.arrow.up.left"
    case queued = "clock"
    case info = "info.circle"
    case skills = "sparkles"
    case mcpServer = "powerplug"
    case mcpPrompt = "bolt.horizontal"
    case effort = "gauge.with.dots.needle.50percent"
    case harnessDot = "circle.fill"
    case noSessions = "bubble.left.and.bubble.right"

    case radioOff = "circle"
    case radioOn = "largecircle.fill.circle"
    case checkboxOff = "square"
    case checkboxOn = "checkmark.square.fill"
    case taskDone = "checkmark.circle.fill"
    case done = "checkmark"

    case modeManual = "shield"
    case modePlan = "list.bullet.clipboard"
    case modeAcceptEdits = "pencil.line"
    case modeAuto = "forward.fill"
    case modeBypass = "exclamationmark.shield"
    case agentBuild = "hammer"

    case warning = "exclamationmark.triangle"
    case strongWarning = "exclamationmark.triangle.fill"
    case noIndicator = "questionmark.square.dashed"

    case services = "server.rack"
    case database = "cylinder"
    case databaseSection = "cylinder.split.1x2"

    case curlyBraces = "curlybraces"
    case cpu
    case coffee = "cup.and.saucer"
    case gears = "gearshape.2"

    case window = "macwindow"
    case desktop = "desktopcomputer"
    case layout = "rectangle.3.group"
    case cursor = "cursorarrow"

    case sliders = "slider.horizontal.3"
    case shieldCheck = "checkmark.shield"
    case key
    case building = "building.2"
    case personKey = "person.badge.key"

    case chart = "chart.bar"
    case report = "chart.bar.doc.horizontal"
    case printer
    case scroll

    case indicatorsTab = "circle.grid.2x2"
    case sessionsTab = "bubble.left.and.text.bubble.right"
    case appearanceTab = "paintpalette"

    case javaFile = "filetype-java"
    case javaScriptFile = "filetype-js"
    case reactFile = "filetype-react"
    case swiftFile = "filetype-swift"
    case typeScriptFile = "filetype-ts"

    case bunLogo = "logo-bun"
    case chakraLogo = "logo-chakra"
    case expoLogo = "logo-expo"
    case javaLogo = "logo-java"
    case quarkusLogo = "logo-quarkus"
    case reactLogo = "logo-react"
    case tailwindLogo = "logo-tailwind"
    case typeScriptLogo = "logo-typescript"
    case viteLogo = "logo-vite"

    case claudeCode = "HarnessClaudeCode"
    case openCode = "HarnessOpenCode"
    case gitChanges = "GitChanges"

    var isAsset: Bool {
        switch self {
        case .javaFile, .javaScriptFile, .reactFile, .swiftFile, .typeScriptFile,
             .bunLogo, .chakraLogo, .expoLogo, .javaLogo, .quarkusLogo, .reactLogo,
             .tailwindLogo, .typeScriptLogo, .viteLogo, .claudeCode, .openCode, .gitChanges:
            true
        default:
            false
        }
    }
}
