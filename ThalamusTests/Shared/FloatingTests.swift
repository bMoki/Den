import Foundation
import Testing
import SwiftUI
@testable import Thalamus

private let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
private let size = CGSize(width: 200, height: 100)

private func frame(_ placement: FloatingPlacement, anchor: CGRect) -> CGRect {
    FloatingLayout.frame(size: size, anchor: anchor, placement: placement, screen: screen)
}

@Test func aFloatingFrameOpensOnTheAskedEdgeCenteredOnTheAnchor() {
    let anchor = CGRect(x: 400, y: 300, width: 40, height: 20)
    #expect(frame(.beside(.top), anchor: anchor) == CGRect(x: 320, y: 324, width: 200, height: 100))
    #expect(frame(.beside(.bottom), anchor: anchor) == CGRect(x: 320, y: 196, width: 200, height: 100))
    #expect(frame(.beside(.trailing), anchor: anchor).minX == 444)
    #expect(frame(.beside(.leading), anchor: anchor).maxX == 396)
}

@Test func aFloatingFrameFlipsWhenTheScreenEdgeIsInTheWay() {
    let nearTop = CGRect(x: 400, y: 760, width: 40, height: 20)
    #expect(frame(.beside(.top), anchor: nearTop).maxY == 756)
    let nearRight = CGRect(x: 900, y: 300, width: 40, height: 20)
    #expect(frame(.beside(.trailing), anchor: nearRight).maxX == 896)
}

@Test func aFloatingFrameStaysOnTheScreen() {
    let nearLeft = CGRect(x: 0, y: 300, width: 40, height: 20)
    #expect(frame(.beside(.top), anchor: nearLeft).minX == 0)
}

@Test func aContextMenuOpensBelowAndRightOfThePointerAndFlipsAtTheEdges() {
    let row = CGRect(x: 100, y: 400, width: 300, height: 40)
    #expect(frame(.at(UnitPoint(x: 0.5, y: 0.5)), anchor: row).origin == CGPoint(x: 250, y: 320))
    let corner = CGRect(x: 900, y: 0, width: 100, height: 40)
    #expect(frame(.at(UnitPoint(x: 0.5, y: 0.5)), anchor: corner).origin == CGPoint(x: 750, y: 20))
}
