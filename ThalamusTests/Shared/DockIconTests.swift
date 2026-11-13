import AppKit
import Foundation
import SwiftUI
import Testing
@testable import Thalamus

private let repository = URL(filePath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

private func pixels(_ rep: NSBitmapImageRep) -> [UInt8] {
    let size = rep.pixelsWide
    var data = [UInt8](repeating: 0, count: size * size * 4)
    guard let image = rep.cgImage, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return data }
    data.withUnsafeMutableBytes { bytes in
        let context = CGContext(data: bytes.baseAddress, width: size, height: size, bitsPerComponent: 8,
                                bytesPerRow: size * 4, space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    }
    return data
}

private func rep(_ image: NSImage, _ size: Int) -> NSBitmapImageRep? {
    image.representations.compactMap { $0 as? NSBitmapImageRep }.first { $0.pixelsWide == size }
}

private func averageDifference(_ image: NSImage, from iconSet: String, size: Int) throws -> Double {
    let file = repository.appending(path: "Thalamus/Assets.xcassets/\(iconSet).appiconset/icon_\(size).png")
    let expected = try #require(NSBitmapImageRep(data: try Data(contentsOf: file)))
    let drawn = try #require(rep(image, size))
    let difference = zip(pixels(drawn), pixels(expected)).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
    return Double(difference) / Double(size * size * 4)
}

private func rgba(_ color: Color) -> [UInt8] {
    guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return [] }
    return [srgb.redComponent, srgb.greenComponent, srgb.blueComponent, 1].map { UInt8(($0 * 255).rounded()) }
}

@Test func theDockIconHasEverySizeOfTheAppIcon() {
    let image = DockIcon.image(style: .padrao, palette: .indigo, dev: false)
    #expect(DockIcon.sizes.allSatisfy { rep(image, $0) != nil })
}

@Test(arguments: [false, true])
func padraoWithIndigoIsTheAppIcon(dev: Bool) throws {
    let image = DockIcon.image(style: .padrao, palette: .indigo, dev: dev)
    for size in DockIcon.sizes {
        let difference = try averageDifference(image, from: dev ? "AppIconDev" : "AppIcon", size: size)
        #expect(difference < 1.5, "\(size) px is \(difference) away from the AppIcon")
    }
}

@Test func ttyDrawsTheArtOfTheBrandDocs() throws {
    let readme = try String(contentsOf: repository.appending(path: "docs/marca/README.md"), encoding: .utf8)
    let art = try #require(readme.components(separatedBy: "```\n").dropFirst(2).first)
    #expect(art.split(separator: "\n", omittingEmptySubsequences: false).dropLast().map(String.init) == DockIcon.ttyArt)
}

@Test func ttyTellsTheCentralDotFromTheHalves() {
    let dotRows = DockIcon.ttyArt.indices.flatMap { row in
        (0..<DockIcon.ttyArt[row].count).filter { DockIcon.isDot(row: row, column: $0) }.map { _ in row }
    }
    #expect(dotRows == Array(repeating: 7, count: 4) + Array(repeating: 8, count: 6)
        + Array(repeating: 9, count: 8) + Array(repeating: 10, count: 6))
}

@Test func ttyDrawsTheSmallSizesInHardPixelsOfThePalette() throws {
    let image = DockIcon.image(style: .tty, palette: .indigo, dev: false)
    let icon = Palette.indigo.appIcon
    let colors = [icon.body, icon.halves, icon.dot].map(rgba) + [[0, 0, 0, 0]]
    for size in [16, 32] {
        let drawn = pixels(try #require(rep(image, size)))
        let strays = stride(from: 0, to: drawn.count, by: 4).filter { !colors.contains(Array(drawn[$0..<$0 + 4])) }
        #expect(strays.isEmpty, "\(size) px has \(strays.count) pixels outside the palette")
    }
}

private func drawingWidth(_ image: NSImage, _ size: Int) throws -> Int {
    let drawn = pixels(try #require(rep(image, size)))
    let columns = (0..<size).filter { column in
        (0..<size).contains { row in drawn[(row * size + column) * 4 + 2] > 0x80 }
    }
    return (columns.last ?? 0) - (columns.first ?? 0) + 1
}

@Test(arguments: [32, 128, 1024])
func ttyDrawsTheMarkAsWideAsPadrao(size: Int) throws {
    let padrao = try drawingWidth(DockIcon.image(style: .padrao, palette: .indigo, dev: false), size)
    let tty = try drawingWidth(DockIcon.image(style: .tty, palette: .indigo, dev: false), size)
    #expect(abs(tty - padrao) <= max(2, padrao / 25), "tty is \(tty) px wide, padrao \(padrao) px")
}

@Test func ttyIsNotThePadraoIcon() throws {
    let image = DockIcon.image(style: .tty, palette: .indigo, dev: false)
    #expect(try averageDifference(image, from: "AppIcon", size: 1024) > 5)
}
