#!/usr/bin/env swift
// Renders the brand laptop artwork (MacBook Pro silhouette, blazing starburst)
// as the social/SEO share image: og.png, 1200×630, solid site-background —
// transparent PNGs render unpredictably on social cards. Raster with layered
// radial glows and additive blending.
// Usage: swift scripts/make-hero.swift <output-dir>
// (render(scale:) can also emit transparent hero PNGs if the site ever wants
//  the artwork inline again.)

import AppKit

guard CommandLine.arguments.count == 2 else {
    print("usage: make-hero.swift <output-dir>")
    exit(1)
}
let outDir = URL(fileURLWithPath: CommandLine.arguments[1])

let W: CGFloat = 920, H: CGFloat = 570

func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

let shellTop = rgba(0x33, 0x3b, 0x45)
let shellBottom = rgba(0x1a, 0x1f, 0x26)
let displayColor = rgba(0x06, 0x08, 0x09)
let amber = rgba(0xff, 0xb0, 0x2e)
let amberLight = rgba(0xff, 0xd4, 0x79)
let coreWhite = rgba(0xff, 0xf3, 0xd9)

/// Draws the laptop scene in 920×570 y-down design coordinates. The caller
/// sets up the canvas, flip, and any background.
func drawScene(_ cg: CGContext) {
    // --- Screen shell + display ---
    let shell = NSBezierPath(roundedRect: NSRect(x: 150, y: 55, width: 620, height: 400),
                             xRadius: 26, yRadius: 26)
    NSGradient(colors: [shellTop, shellBottom])!.draw(in: shell, angle: -90)

    let displayRect = NSRect(x: 167, y: 72, width: 586, height: 366)
    let display = NSBezierPath(roundedRect: displayRect, xRadius: 14, yRadius: 14)
    displayColor.setFill()
    display.fill()

    // Display notch (camera housing): hangs from the top edge of the display —
    // flat on top, rounded only at the bottom corners. Drawn as a rounded rect
    // that starts above the display edge, clipped to the display so the top
    // rounding is cut off flush.
    cg.saveGState()
    display.addClip()
    shellBottom.setFill()
    NSBezierPath(roundedRect: NSRect(x: 425, y: 58, width: 70, height: 28),
                 xRadius: 8, yRadius: 8).fill()
    cg.restoreGState()

    // --- Starburst, clipped to the display, additive so light accumulates ---
    cg.saveGState()
    display.addClip()
    cg.setBlendMode(.plusLighter)

    let core = CGPoint(x: 460, y: 400)

    func radialGlow(radius: CGFloat, color: NSColor, alpha: CGFloat) {
        let gradient = NSGradient(colors: [color.withAlphaComponent(alpha),
                                           color.withAlphaComponent(0)])!
        gradient.draw(fromCenter: NSPoint(x: core.x, y: core.y), radius: 0,
                      toCenter: NSPoint(x: core.x, y: core.y), radius: radius,
                      options: [])
    }

    // Broad ambient glow → tight hot core.
    radialGlow(radius: 230, color: amber, alpha: 0.35)
    radialGlow(radius: 110, color: amberLight, alpha: 0.55)
    radialGlow(radius: 48, color: coreWhite, alpha: 0.85)

    // Tapered rays: angle from vertical (degrees), length. Each drawn in three
    // additive passes (wide faint → narrow bright) for a bloomed-light look.
    let rays: [(CGFloat, CGFloat)] = [
        (0, 315), (-18, 265), (18, 265), (-42, 240), (42, 240), (-72, 205), (72, 205),
    ]
    func ray(angleDeg: CGFloat, length: CGFloat, width: CGFloat, color: NSColor, alpha: CGFloat) {
        let a = angleDeg * .pi / 180
        let dir = CGPoint(x: sin(a), y: -cos(a))
        let perp = CGPoint(x: cos(a), y: sin(a))
        let tip = CGPoint(x: core.x + dir.x * length, y: core.y + dir.y * length)
        let path = NSBezierPath()
        path.move(to: NSPoint(x: core.x - perp.x * width / 2, y: core.y - perp.y * width / 2))
        path.line(to: NSPoint(x: tip.x, y: tip.y))
        path.line(to: NSPoint(x: core.x + perp.x * width / 2, y: core.y + perp.y * width / 2))
        path.close()
        color.withAlphaComponent(alpha).setFill()
        path.fill()
    }
    for (angle, length) in rays {
        ray(angleDeg: angle, length: length, width: 26, color: amber, alpha: 0.16)
        ray(angleDeg: angle, length: length * 0.99, width: 13, color: amber, alpha: 0.45)
        ray(angleDeg: angle, length: length * 0.97, width: 6.5, color: amberLight, alpha: 0.95)
    }

    // Hot center dot.
    coreWhite.setFill()
    NSBezierPath(ovalIn: NSRect(x: core.x - 11, y: core.y - 11, width: 22, height: 22)).fill()
    cg.restoreGState()

    // --- Base deck with front lip notch ---
    let base = NSBezierPath(roundedRect: NSRect(x: 105, y: 455, width: 710, height: 22),
                            xRadius: 11, yRadius: 11)
    NSGradient(colors: [shellTop, shellBottom])!.draw(in: base, angle: -90)
    displayColor.setFill()
    NSBezierPath(roundedRect: NSRect(x: 425, y: 455, width: 70, height: 9),
                 xRadius: 4.5, yRadius: 4.5).fill()
}

/// Transparent hero at a given scale (kept for future inline use).
func render(scale: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(W * scale), pixelsHigh: Int(H * scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext
    cg.translateBy(x: 0, y: H * scale)
    cg.scaleBy(x: scale, y: -scale)
    drawScene(cg)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

/// 1200×630 social card: solid site background, laptop scaled to fill.
func renderOG() -> NSBitmapImageRep {
    let ogW: CGFloat = 1200, ogH: CGFloat = 630
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(ogW), pixelsHigh: Int(ogH),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    let cg = ctx.cgContext

    // Solid site background (#0b0d10) — social cards dislike transparency.
    rgba(0x0b, 0x0d, 0x10).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: ogW, height: ogH)).fill()

    // Fit the 920×570 design into 1200×630: scale by height, center by width.
    let scale = ogH / H                       // 1.105…
    let xOffset = (ogW - W * scale) / 2       // ≈ 92
    cg.translateBy(x: xOffset, y: ogH)
    cg.scaleBy(x: scale, y: -scale)
    drawScene(cg)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let og = renderOG()
try og.representation(using: .png, properties: [:])!
    .write(to: outDir.appendingPathComponent("og.png"))
print("wrote og.png (1200×630)")

// Transparent product render for the website showcase section (1x + 2x).
for (name, scale) in [("hero-mac.png", CGFloat(1)), ("hero-mac@2x.png", CGFloat(2))] {
    let rep = render(scale: scale)
    try rep.representation(using: .png, properties: [:])!
        .write(to: outDir.appendingPathComponent(name))
    print("wrote \(name) (\(Int(W * scale))×\(Int(H * scale)))")
}
