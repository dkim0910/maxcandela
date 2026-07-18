#!/usr/bin/env swift
// Generates the MaxCandela app icon: a warm sun glyph on a dark rounded
// gradient, rendered at every size macOS needs, as an .iconset directory.
// Usage: swift scripts/make-icon.swift <output.iconset>
// Then:  iconutil -c icns <output.iconset> -o AppIcon.icns

import AppKit

guard CommandLine.arguments.count == 2 else {
    print("usage: make-icon.swift <output.iconset>")
    exit(1)
}
let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func drawIcon(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let size = CGFloat(pixels)
    // macOS icon grid: content inset ~10% with a continuous-corner rect.
    let inset = size * 0.10
    let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = rect.width * 0.225
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    // Dark night-sky gradient background.
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.18, alpha: 1),
        NSColor(calibratedRed: 0.04, green: 0.05, blue: 0.08, alpha: 1),
    ])!
    gradient.draw(in: path, angle: -90)

    // Sun: radial glow + solid core, in the brand amber.
    let center = NSPoint(x: rect.midX, y: rect.midY)
    let glowRadius = rect.width * 0.34
    let glow = NSGradient(colors: [
        NSColor(calibratedRed: 1.0, green: 0.69, blue: 0.18, alpha: 0.85),
        NSColor(calibratedRed: 1.0, green: 0.69, blue: 0.18, alpha: 0.0),
    ])!
    path.addClip()
    glow.draw(fromCenter: center, radius: 0, toCenter: center, radius: glowRadius * 1.6, options: [])

    let coreRadius = rect.width * 0.17
    NSColor(calibratedRed: 1.0, green: 0.75, blue: 0.25, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: center.x - coreRadius, y: center.y - coreRadius,
                                width: coreRadius * 2, height: coreRadius * 2)).fill()

    // Eight rays.
    NSColor(calibratedRed: 1.0, green: 0.75, blue: 0.25, alpha: 1).setStroke()
    let rayInner = coreRadius * 1.45
    let rayOuter = coreRadius * 1.95
    for i in 0..<8 {
        let angle = CGFloat(i) * .pi / 4
        let ray = NSBezierPath()
        ray.lineWidth = max(1, rect.width * 0.035)
        ray.lineCapStyle = .round
        ray.move(to: NSPoint(x: center.x + cos(angle) * rayInner, y: center.y + sin(angle) * rayInner))
        ray.line(to: NSPoint(x: center.x + cos(angle) * rayOuter, y: center.y + sin(angle) * rayOuter))
        ray.stroke()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

// Every size/scale pair the iconset format wants.
let entries: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for entry in entries {
    let rep = drawIcon(pixels: entry.pixels)
    let png = rep.representation(using: .png, properties: [:])!
    try png.write(to: outDir.appendingPathComponent("\(entry.name).png"))
}
print("Wrote \(entries.count) images to \(outDir.path)")
