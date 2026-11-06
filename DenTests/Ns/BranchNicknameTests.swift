import Testing
@testable import Den

@Test func aNicknameIsOneTrimmedLineAndBlankMeansNone() {
    #expect(BranchNickname.normalized("  Agenda\nrecorrente  2 ") == "Agenda recorrente  2")
    #expect(BranchNickname.normalized("   ") == nil)
    #expect(BranchNickname.normalized("") == nil)
}

@Test func aNicknameKeepsAtMostFortyCharacters() {
    #expect(BranchNickname.normalized(String(repeating: "á", count: 41)) == String(repeating: "á", count: 40))
}

@Test func searchFindsANicknameIgnoringCaseAndAccents() {
    #expect(BranchNickname.matches("Agênda recorrente", "agenda"))
    #expect(BranchNickname.matches("Agenda recorrente", "RECORR"))
    #expect(!BranchNickname.matches("Agenda recorrente", "tiss"))
    #expect(!BranchNickname.matches(nil, "agenda"))
}
