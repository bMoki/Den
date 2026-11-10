import AppKit

enum FolderPicker {
    static func choose(prompt: String, from directory: URL?) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = prompt
        panel.directoryURL = directory
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
