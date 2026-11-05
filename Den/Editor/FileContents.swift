import Foundation

nonisolated enum FileContents: Equatable, Sendable {
    case text(String)
    case image(Data)
    case unreadable(String)

    static let sizeLimit = 4 * 1024 * 1024
    static let imageSizeLimit = 64 * 1024 * 1024

    static func read(_ url: URL) -> FileContents {
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let isImage = FileTreeMark.isImage(url.lastPathComponent)
        if size > (isImage ? imageSizeLimit : sizeLimit) {
            return .unreadable("Arquivo grande demais para abrir aqui (\(ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file))).")
        }
        guard let data = try? Data(contentsOf: url) else { return .unreadable("Não consegui abrir este arquivo.") }
        if isImage { return .image(data) }
        if data.prefix(8192).contains(0) { return .unreadable("Arquivo binário.") }
        guard let text = String(data: data, encoding: .utf8) else { return .unreadable("Este arquivo não está em UTF-8.") }
        return .text(text)
    }
}
