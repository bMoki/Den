import Testing
import SwiftUI
@testable import Thalamus

@Test func aMenuWithoutASingleIconReservesNoIconColumn() {
    let sections = [ThalamusMenuSection(items: [
        ThalamusMenuItem(id: "a", title: "A"),
        ThalamusMenuItem(id: "b", title: "B"),
    ])]

    #expect(ThalamusMenuSection.showsIcons(in: sections) == false)
}

@Test func oneIconAnywhereReservesTheColumnForEveryRow() {
    let sections = [
        ThalamusMenuSection(id: "plain", items: [ThalamusMenuItem(id: "a", title: "A")]),
        ThalamusMenuSection(id: "iconed", items: [
            ThalamusMenuItem(id: "b", title: "B", icon: .symbol("hammer", Theme.added)),
        ]),
    ]

    #expect(ThalamusMenuSection.showsIcons(in: sections))
}

@Test func anItemIsALeafUntilItIsGivenChildren() {
    let leaf = ThalamusMenuItem(id: "leaf", title: "Nova pasta")
    let parent = ThalamusMenuItem(id: "parent", title: "Nova sessão com",
                             children: [ThalamusMenuSection(items: [leaf])])

    #expect(leaf.children.isEmpty)
    #expect(parent.children.flatMap(\.items).map(\.id) == ["leaf"])
}

@Test func anItemIsOnlyDestructiveWhenItSaysSo() {
    let plain = ThalamusMenuItem(id: "rename", title: "Renomear")
    let destructive = ThalamusMenuItem(id: "delete", title: "Apagar sessão…", isDestructive: true)

    #expect(plain.isDestructive == false)
    #expect(destructive.isDestructive)
}

@Test func aDangerousActionSitsInItsOwnSectionSoItGetsASeparator() {
    let sections = [
        ThalamusMenuSection(id: "edit", items: [ThalamusMenuItem(id: "rename", title: "Renomear")]),
        ThalamusMenuSection(id: "danger", items: [
            ThalamusMenuItem(id: "delete", title: "Apagar sessão…", isDestructive: true),
        ]),
    ]

    #expect(sections.allSatisfy { $0.header == nil })
    #expect(sections.last?.items.allSatisfy(\.isDestructive) == true)
}
