import Testing
@testable import Thalamus

@Test func sessionStatesSortByPrecedence() {
    #expect(SessionState.allCases.sorted() == [.awaitingDecision, .outOfTokens, .newReply, .thinking])
}

@Test func sessionStatesUseTheGlossaryNames() {
    #expect(SessionState.allCases.map(\.name) == ["Aguardando decisão", "Tokens esgotados", "Resposta nova", "Pensando"])
}

@Test func prevailingStateCountsOnlyTheSessionsInIt() {
    let prevailing = PrevailingState([.thinking, .newReply, nil, .newReply, .thinking])
    #expect(prevailing?.state == .newReply)
    #expect(prevailing?.count == 2)
    #expect(prevailing?.label == "2 respostas novas")
}

@Test func prevailingStateIsAbsentWithoutAnyState() {
    #expect(PrevailingState([nil, nil]) == nil)
    #expect(PrevailingState([SessionState?]()) == nil)
}

@Test func stateLabelsReadAsACount() {
    #expect(SessionState.awaitingDecision.label(count: 2) == "2 aguardando decisão")
    #expect(SessionState.newReply.label(count: 1) == "1 resposta nova")
    #expect(SessionState.thinking.label(count: 3) == "3 pensando")
    #expect(SessionState.outOfTokens.label(count: 1) == "1 tokens esgotados")
}
