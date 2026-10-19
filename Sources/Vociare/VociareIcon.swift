import AppKit

/// Vociare's mark, a speech bubble holding a waveform. It is drawn in code so the app icon and the menu bar share one shape.
enum VociareIcon {
    private static let barHeights: [CGFloat] = [0.25, 0.45, 0.62, 0.45, 0.25]
    private static let gradientTop = CGColor(red: 1.0, green: 0.62, blue: 0.26, alpha: 1)
    private static let gradientBottom = CGColor(red: 0.93, green: 0.29, blue: 0.42, alpha: 1)

    /// Outlined when idle and filled while recording, like the `.fill` variants of SF Symbols.
    static func menuBarImage(recording: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 20, height: 18), flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            drawGlyph(in: rect.insetBy(dx: 1.5, dy: 1.5), context: context, color: .black, filled: recording)
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Writes the PNGs that `iconutil` packs into AppIcon.icns.
    static func writeIconSet(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try [16, 32, 128, 256, 512].flatMap { size in [(size, 1), (size, 2)] }.forEach { size, scale in
            let name = scale == 1 ? "icon_\(size)x\(size).png" : "icon_\(size)x\(size)@2x.png"
            try appIconPNG(pixels: size * scale).write(to: directory.appendingPathComponent(name))
        }
    }

    private static func appIconPNG(pixels: Int) throws -> Data {
        guard
            let bitmap = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
                hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
            let context = NSGraphicsContext(bitmapImageRep: bitmap)?.cgContext
        else { throw CocoaError(.fileWriteUnknown) }
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        drawAppIcon(context)
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw CocoaError(.fileWriteUnknown) }
        return png
    }

    // Apple's macOS icon grid: an 824 pt body centred on a 1024 pt canvas, leaving room for the shadow.
    private static func drawAppIcon(_ context: CGContext) {
        let shape = CGPath(
            roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 185, cornerHeight: 185, transform: nil)

        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(gray: 0, alpha: 0.3))
        context.addPath(shape)
        context.fillPath()
        context.restoreGState()

        context.saveGState()
        context.addPath(shape)
        context.clip()
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [gradientTop, gradientBottom] as CFArray, locations: [0, 1])!
        context.drawLinearGradient(gradient, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
        context.restoreGState()

        drawGlyph(in: CGRect(x: 242, y: 297, width: 540, height: 450), context: context, color: .white, filled: true)
    }

    /// A filled bubble has the bars cut out of it, so whatever is behind it (the gradient, the menu bar) shows through.
    private static func drawGlyph(in rect: CGRect, context: CGContext, color: CGColor, filled: Bool) {
        let tailHeight = rect.height * 0.2
        let body = CGRect(x: rect.minX, y: rect.minY + tailHeight, width: rect.width, height: rect.height - tailHeight)
        let radius = body.height * 0.32
        let tail = CGMutablePath()
        tail.addLines(between: [
            CGPoint(x: body.minX + body.width * 0.25, y: body.minY + radius * 0.6),
            CGPoint(x: body.minX + body.width * 0.12, y: rect.minY),
            CGPoint(x: body.minX + body.width * 0.5, y: body.minY + radius * 0.6),
        ])
        tail.closeSubpath()
        let bubble = CGPath(roundedRect: body, cornerWidth: radius, cornerHeight: radius, transform: nil).union(tail)

        let barWidth = body.width * 0.085
        let gap = body.width * 0.065
        let barsWidth = CGFloat(barHeights.count) * barWidth + CGFloat(barHeights.count - 1) * gap
        let bars = CGMutablePath()
        barHeights.enumerated().forEach { index, relativeHeight in
            let height = body.height * relativeHeight
            let x = body.midX - barsWidth / 2 + CGFloat(index) * (barWidth + gap)
            bars.addRoundedRect(
                in: CGRect(x: x, y: body.midY - height / 2, width: barWidth, height: height),
                cornerWidth: barWidth / 2, cornerHeight: barWidth / 2)
        }

        context.saveGState()
        defer { context.restoreGState() }
        context.setFillColor(color)
        context.setStrokeColor(color)
        context.beginTransparencyLayer(auxiliaryInfo: nil)
        context.addPath(bubble)
        if filled {
            context.fillPath()
            context.setBlendMode(.clear)
        } else {
            context.setLineWidth(1.5)
            context.setLineJoin(.round)
            context.strokePath()
        }
        context.addPath(bars)
        context.fillPath()
        context.endTransparencyLayer()
    }
}
