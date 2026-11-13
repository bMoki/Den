import AppKit
import SwiftUI

nonisolated enum DockIcon {
    static let sizes = [16, 32, 64, 128, 256, 512, 1024]

    static let ttyArt = [
        "     .::.                  .::.",
        "   O@@@@@@0:            :0@@@@@@O",
        "  0@@@@@@@@@0.        .0@@@@@@@@@0",
        " 0@@@@@@@@@@@@:      :@@@@@@@@@@@@0",
        ".@@@@@@@@@@@@@@:    :@@@@@@@@@@@@@@.",
        "o@@@@@@@@@@@@@@@.  .@@@@@@@@@@@@@@@o",
        "O@@@@@@@@@@@@@@0:  :0@@@@@@@@@@@@@@O",
        "o@@@@@@@@@@@@0. @@@@ .0@@@@@@@@@@@@o",
        ".@@@@@@@@@@@@  @@@@@@  @@@@@@@@@@@@.",
        " 0@@@@@@@@@@0 @@@@@@@@ 0@@@@@@@@@@0",
        " :@@@@@@@@@@@. @@@@@@ .@@@@@@@@@@@:",
        "  O@@@@@@@@@@@o      o@@@@@@@@@@@O",
        "   O@@@@@@@@@@@@0..0@@@@@@@@@@@@O",
        "    o@@@@@@@@@@@0  0@@@@@@@@@@@o",
        "     .0@@@@@@@@0    0@@@@@@@@0.",
        "       .O0@@@O:      :O@@@0O.",
    ]

    private static let canvas: CGFloat = 1024
    private static let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    private static let bodyRadius: CGFloat = 185
    private static let artColumns = 36
    private static let artMiddle = 17...18
    private static let bandShare: CGFloat = 0.25

    private struct Mark {
        var halfCenterX: CGFloat
        var halfSize: CGSize
        var tilt: CGFloat
        var dotCenter: CGPoint
        var dotSize: CGFloat
        var ringWidth: CGFloat

        var width: CGFloat {
            let tilt = self.tilt * .pi / 180
            let reach = hypot(halfSize.width / 2 * cos(tilt), halfSize.height / 2 * sin(tilt))
            return 100 - 2 * (halfCenterX - reach)
        }
    }

    private static let mark = Mark(halfCenterX: 36, halfSize: CGSize(width: 26, height: 44), tilt: 14,
                                   dotCenter: CGPoint(x: 50, y: 53), dotSize: 14, ringWidth: 3)
    private static let markOnPixelGrid = Mark(halfCenterX: 28.64, halfSize: CGSize(width: 21, height: 46.6),
                                              tilt: 12, dotCenter: CGPoint(x: 50, y: 50), dotSize: 26.4,
                                              ringWidth: 5.4)

    static func image(style: Style, palette: Palette, dev: Bool) -> NSImage {
        let image = NSImage(size: CGSize(width: canvas, height: canvas))
        for size in sizes {
            guard let bitmap = bitmap(size, style: style, colors: palette.appIcon, dev: dev) else { continue }
            let rep = NSBitmapImageRep(cgImage: bitmap)
            rep.size = image.size
            image.addRepresentation(rep)
        }
        return image
    }

    static func isDot(row: Int, column: Int) -> Bool {
        let line = Array(ttyArt[row])
        guard line.indices.contains(column), line[column] == "@" else { return false }
        var start = column
        var end = column
        while start > 0, line[start - 1] == "@" { start -= 1 }
        while end < line.count - 1, line[end + 1] == "@" { end += 1 }
        return (start...end).overlaps(artMiddle) && start > 0 && line[start - 1] == " "
    }

    private static func bitmap(_ size: Int, style: Style, colors: Palette.AppIcon, dev: Bool) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB), let bitmap = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        let scale = CGFloat(size) / canvas
        bitmap.translateBy(x: 0, y: CGFloat(size))
        bitmap.scaleBy(x: scale, y: -scale)
        let context = NSGraphicsContext(cgContext: bitmap, flipped: true)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let small = size <= 32
        if style.appIcon == .characters, small { context.shouldAntialias = false }
        NSColor(colors.body).setFill()
        bodyPath().fill()
        let shape = size == 16 ? markOnPixelGrid : mark
        switch style.appIcon {
        case .shapes: draw(shape, colors: colors)
        case .characters: small ? draw(shape, colors: colors) : drawArt(colors: colors)
        }
        if dev { drawBand(colors: colors) }
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.makeImage()
    }

    private static func bodyPath() -> NSBezierPath {
        NSBezierPath(roundedRect: body, xRadius: bodyRadius, yRadius: bodyRadius)
    }

    private static func draw(_ mark: Mark, colors: Palette.AppIcon) {
        NSGraphicsContext.saveGraphicsState()
        var box = AffineTransform(translationByX: body.minX, byY: body.minY)
        box.scale(body.width / 100)
        (box as NSAffineTransform).concat()
        NSColor(colors.halves).setFill()
        let size = mark.halfSize
        for (x, tilt) in [(mark.halfCenterX, -mark.tilt), (100 - mark.halfCenterX, mark.tilt)] {
            let half = NSBezierPath(ovalIn: CGRect(x: -size.width / 2, y: -size.height / 2,
                                                   width: size.width, height: size.height))
            var place = AffineTransform(translationByX: x, byY: 50)
            place.rotate(byDegrees: tilt)
            half.transform(using: place)
            half.fill()
        }
        let dot = NSBezierPath(ovalIn: CGRect(x: mark.dotCenter.x - mark.dotSize / 2,
                                              y: mark.dotCenter.y - mark.dotSize / 2,
                                              width: mark.dotSize, height: mark.dotSize))
        NSColor(colors.dot).setFill()
        dot.fill()
        dot.lineWidth = mark.ringWidth
        NSColor(colors.body).setStroke()
        dot.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    private static func drawArt(colors: Palette.AppIcon) {
        let advance = ("@" as NSString).size(withAttributes: [.font: Style.ttyBoldFont(ofSize: 1)]).width
        let points = body.width * mark.width / 100 / (CGFloat(artColumns) * advance)
        let font = Style.ttyBoldFont(ofSize: points)
        let lineHeight = points * 1.2
        let left = canvas / 2 - CGFloat(artColumns) * advance * points / 2
        let top = canvas / 2 - CGFloat(ttyArt.count) * lineHeight / 2
        let halves = NSColor(colors.halves)
        let dot = NSColor(colors.dot)
        for (row, line) in ttyArt.enumerated() {
            let text = NSMutableAttributedString()
            for (column, character) in line.enumerated() {
                let color = isDot(row: row, column: column) ? dot : halves
                text.append(NSAttributedString(string: String(character),
                                               attributes: [.font: font, .foregroundColor: color]))
            }
            let y = top + CGFloat(row) * lineHeight + (lineHeight - font.ascender + font.descender) / 2
            text.draw(at: CGPoint(x: left, y: y))
        }
    }

    private static func drawBand(colors: Palette.AppIcon) {
        bodyPath().addClip()
        let band = CGRect(x: body.minX, y: body.maxY - body.height * bandShare,
                          width: body.width, height: body.height * bandShare)
        NSColor(colors.band).setFill()
        band.fill()
        let font = Style.bandFont(ofSize: band.height * 0.53)
        let label = NSAttributedString(string: "DEV", attributes: [.font: font, .foregroundColor: NSColor(colors.onBand)])
        let baseline = band.midY + font.capHeight / 2
        label.draw(at: CGPoint(x: band.midX - label.size().width / 2, y: baseline - font.ascender))
    }
}
