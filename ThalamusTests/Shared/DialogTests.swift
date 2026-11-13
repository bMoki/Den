import Testing
@testable import Thalamus

@Test func returnNeverPicksADestructiveChoice() {
    let save = ConfirmationChoice(title: "Salvar e fechar") {}
    let discard = ConfirmationChoice(title: "Fechar sem salvar", isDestructive: true) {}
    #expect(ConfirmationDialog.defaultIndex(of: [save, discard]) == 0)
    #expect(ConfirmationDialog.defaultIndex(of: [discard, save]) == 1)
    #expect(ConfirmationDialog.defaultIndex(of: [discard]) == nil)
}
