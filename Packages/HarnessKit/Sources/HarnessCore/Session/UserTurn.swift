import Foundation

public struct MediaAttachment: Sendable, Equatable {
    public let mediaType: String
    public let data: Data

    public init(mediaType: String, data: Data) {
        self.mediaType = mediaType
        self.data = data
    }

    public var isImage: Bool { mediaType.hasPrefix("image/") }
}

public struct UserTurn: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var text: String
    public var attachments: [MediaAttachment]

    public init(id: UUID = UUID(), text: String, attachments: [MediaAttachment] = []) {
        self.id = id
        self.text = text
        self.attachments = attachments
    }
}
