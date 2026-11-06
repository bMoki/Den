import Testing
@testable import Den

private let sent = ["one", "two", "three"]

@Test func upStartsAtTheMostRecentMessageAndStopsAtTheOldest() {
    var history = ComposerHistory()
    #expect(history.older(in: sent, current: "") == "three")
    #expect(history.older(in: sent, current: "three") == "two")
    #expect(history.older(in: sent, current: "two") == "one")
    #expect(history.older(in: sent, current: "one") == nil)
    #expect(history.position == 0)
}

@Test func downPastTheMostRecentMessageGivesTheDraftBack() {
    var history = ComposerHistory()
    _ = history.older(in: sent, current: "meio escrito")
    _ = history.older(in: sent, current: "three")
    #expect(history.newer() == "three")
    #expect(history.newer() == "meio escrito")
    #expect(!history.isBrowsing)
    #expect(history.newer() == nil)
}

@Test func withNothingSentUpDoesNothing() {
    var history = ComposerHistory()
    #expect(history.older(in: [], current: "draft") == nil)
    #expect(!history.isBrowsing)
}

@Test func leavingForgetsThePlaceAndTheDraft() {
    var history = ComposerHistory()
    _ = history.older(in: sent, current: "draft")
    history.leave()
    #expect(!history.isBrowsing)
    #expect(history.older(in: sent, current: "") == "three")
    #expect(history.newer() == "")
}

@Test func messagesSentWhileBrowsingDoNotShiftThePlace() {
    var history = ComposerHistory()
    _ = history.older(in: sent, current: "")
    _ = history.older(in: sent + ["four"], current: "three")
    #expect(history.newer() == "three")
    #expect(history.canGoOlder(in: []))
}
