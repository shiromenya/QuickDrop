#!/usr/bin/env swift
import AppKit

guard CommandLine.arguments.count >= 2 else {
    fputs("Usage: generate-icon.swift <output-icns-path>\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let fileManager = FileManager.default
let iconsetDir = fileManager.temporaryDirectory
    .appendingPathComponent("QuickDrop-\(UUID().uuidString).iconset")

try? fileManager.removeItem(at: iconsetDir)
try fileManager.createDirectory(at: iconsetDir, withIntermediateDirectories: true)
defer { try? fileManager.removeItem(at: iconsetDir) }

let iconEntries: [(pixels: Int, filename: String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

func drawIcon(in rect: NSRect) {
    let size = rect.width
    let inset = size * 0.09
    let cardRect = rect.insetBy(dx: inset, dy: inset)
    let cornerRadius = cardRect.width * 0.225
    let squircle = NSBezierPath(roundedRect: cardRect, xRadius: cornerRadius, yRadius: cornerRadius)

    // Deep indigo-slate background gradient
    NSGraphicsContext.saveGraphicsState()
    squircle.addClip()

    let bgGradient = NSGradient(
        starting: NSColor(calibratedRed: 0.08, green: 0.13, blue: 0.25, alpha: 1.0),
        ending: NSColor(calibratedRed: 0.04, green: 0.07, blue: 0.15, alpha: 1.0)
    )
    bgGradient?.draw(in: cardRect, angle: -90)

    // Subtle 3-edge inner glow (left, top, right) fading out before bottom edge
    let glowColor = NSColor(calibratedRed: 0.22, green: 0.70, blue: 1.0, alpha: 1.0)
    let glowDepth = cardRect.width * 0.18

    let topGlow = NSGradient(colors: [
        glowColor.withAlphaComponent(0.58),
        glowColor.withAlphaComponent(0.0)
    ])
    let topRect = NSRect(
        x: cardRect.minX,
        y: cardRect.maxY - glowDepth,
        width: cardRect.width,
        height: glowDepth
    )
    topGlow?.draw(in: topRect, angle: -90)

    let leftRect = NSRect(
        x: cardRect.minX,
        y: cardRect.minY + cardRect.height * 0.12,
        width: glowDepth,
        height: cardRect.height * 0.88
    )
    topGlow?.draw(in: leftRect, angle: 0)

    let rightRect = NSRect(
        x: cardRect.maxX - glowDepth,
        y: cardRect.minY + cardRect.height * 0.12,
        width: glowDepth,
        height: cardRect.height * 0.88
    )
    topGlow?.draw(in: rightRect, angle: 180)

    // Crisp luminous rim along top, left, and right
    let rimPath = NSBezierPath()
    let strokeInset = max(1.0, size * 0.012)
    let rimRect = cardRect.insetBy(dx: strokeInset, dy: strokeInset)
    let r = max(2.0, cornerRadius - strokeInset)

    rimPath.move(to: NSPoint(x: rimRect.minX, y: rimRect.minY + r * 1.4))
    rimPath.line(to: NSPoint(x: rimRect.minX, y: rimRect.maxY - r))
    rimPath.appendArc(
        withCenter: NSPoint(x: rimRect.minX + r, y: rimRect.maxY - r),
        radius: r,
        startAngle: 180,
        endAngle: 90,
        clockwise: true
    )
    rimPath.line(to: NSPoint(x: rimRect.maxX - r, y: rimRect.maxY))
    rimPath.appendArc(
        withCenter: NSPoint(x: rimRect.maxX - r, y: rimRect.maxY - r),
        radius: r,
        startAngle: 90,
        endAngle: 0,
        clockwise: true
    )
    rimPath.line(to: NSPoint(x: rimRect.maxX, y: rimRect.minY + r * 1.4))

    glowColor.withAlphaComponent(0.9).setStroke()
    rimPath.lineWidth = max(1.0, size * 0.022)
    rimPath.lineCapStyle = .round
    rimPath.stroke()

    NSGraphicsContext.restoreGraphicsState()

    // Subtle outer border for contrast in Finder/Dock
    NSColor.white.withAlphaComponent(0.14).setStroke()
    squircle.lineWidth = max(1.0, size * 0.008)
    squircle.stroke()

    // Centered AirDrop wave symbol
    let baseConfig = NSImage.SymbolConfiguration(pointSize: size * 0.38, weight: .semibold)
    let paletteConfig = NSImage.SymbolConfiguration(paletteColors: [
        NSColor(calibratedRed: 0.92, green: 0.97, blue: 1.0, alpha: 1.0)
    ])
    if let symbol = NSImage(systemSymbolName: "dot.radiowaves.left.and.right", accessibilityDescription: nil)?
        .withSymbolConfiguration(baseConfig.applying(paletteConfig)) {
        let symbolSize = symbol.size
        let maxSide = max(symbolSize.width, symbolSize.height, 1)
        let targetMax = cardRect.width * 0.56
        let scale = targetMax / maxSide
        let drawSize = NSSize(width: symbolSize.width * scale, height: symbolSize.height * scale)
        let drawRect = NSRect(
            x: rect.midX - drawSize.width / 2,
            y: rect.midY - drawSize.height / 2,
            width: drawSize.width,
            height: drawSize.height
        )
        symbol.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }
}

let uniquePixels = Set(iconEntries.map(\.pixels)).sorted()
for px in uniquePixels {
    guard let bitmapRep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: px,
        pixelsHigh: px,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        continue
    }
    bitmapRep.size = NSSize(width: px, height: px)

    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: bitmapRep) else { continue }
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    drawIcon(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()

    guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else { continue }
    for entry in iconEntries where entry.pixels == px {
        try pngData.write(to: iconsetDir.appendingPathComponent(entry.filename))
    }
}

try fileManager.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDir.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    fputs("iconutil exited with status \(process.terminationStatus)\n", stderr)
    exit(process.terminationStatus)
}
