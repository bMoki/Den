import Testing
import HarnessCore

@Test func aKnobOffersOnlyTheValuesAmongItsOptions() {
    let knob = HarnessKnob(id: "model", category: .model, name: "Modelo",
                           options: [.init(value: "opus", label: "Opus")])
    #expect(knob.offers("opus"))
    #expect(!knob.offers("Opus"))
    #expect(!knob.offers("haiku"))
}
