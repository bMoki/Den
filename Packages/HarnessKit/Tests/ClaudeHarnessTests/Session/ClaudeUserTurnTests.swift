import Testing
import Foundation
import HarnessCore
@testable import ClaudeHarness

@Test func aTextOnlyTurnKeepsTheStringContentWire() {
    let line = ClaudeSession.userTurn(UserTurn(text: "hi"))
    #expect(line["message"]?["content"]?.stringValue == "hi")
}

@Test func aTurnWithImagesBecomesContentBlocks() {
    let data = Data([0x89, 0x50, 0x4E, 0x47])
    let line = ClaudeSession.userTurn(UserTurn(
        text: "what is this?",
        attachments: [MediaAttachment(mediaType: "image/png", data: data)]
    ))
    let blocks = line["message"]?["content"]?.arrayValue
    #expect(blocks?.count == 2)
    #expect(blocks?[0]["type"]?.stringValue == "image")
    #expect(blocks?[0]["source"]?["type"]?.stringValue == "base64")
    #expect(blocks?[0]["source"]?["media_type"]?.stringValue == "image/png")
    #expect(blocks?[0]["source"]?["data"]?.stringValue == data.base64EncodedString())
    #expect(blocks?[1]["type"]?.stringValue == "text")
    #expect(blocks?[1]["text"]?.stringValue == "what is this?")
}

@Test func aPDFBecomesADocumentBlock() {
    let data = Data([0x25, 0x50, 0x44, 0x46])
    let line = ClaudeSession.userTurn(UserTurn(
        text: "resuma este arquivo",
        attachments: [MediaAttachment(mediaType: "application/pdf", data: data)]
    ))
    let blocks = line["message"]?["content"]?.arrayValue
    #expect(blocks?.count == 2)
    #expect(blocks?[0]["type"]?.stringValue == "document")
    #expect(blocks?[0]["source"]?["type"]?.stringValue == "base64")
    #expect(blocks?[0]["source"]?["media_type"]?.stringValue == "application/pdf")
    #expect(blocks?[0]["source"]?["data"]?.stringValue == data.base64EncodedString())
}

@Test func anImageOnlyTurnHasNoEmptyTextBlock() {
    let line = ClaudeSession.userTurn(UserTurn(
        text: "",
        attachments: [MediaAttachment(mediaType: "image/png", data: Data([1]))]
    ))
    let blocks = line["message"]?["content"]?.arrayValue
    #expect(blocks?.count == 1)
    #expect(blocks?[0]["type"]?.stringValue == "image")
}

@Test func aTurnCarriesItsIDSoTheHarnessCanReportItsQueue() throws {
    let id = try #require(UUID(uuidString: "6ECA0966-94A8-4C39-AF2D-2B18ACA423C8"))
    let line = ClaudeSession.userTurn(UserTurn(id: id, text: "hi"))
    #expect(line["uuid"]?.stringValue == "6eca0966-94a8-4c39-af2d-2b18aca423c8")
}
