#!/usr/bin/env swift
// Generates every brand raster from the single source logo
// (assets/brand/MaxCandela_Logo.png — transparent MacBook + starburst).
//
// Previously this script *drew* the mark procedurally; it now resamples the
// supplied artwork so the logo has exactly one source of truth. Replace that
// PNG and re-run to update everything.
//
// Usage: swift scripts/make-icon.swift <output.iconset> [--all]
//   <output.iconset>  macOS iconset directory (bundle-macos.sh passes this)
//   --all             also refresh the checked-in app + web assets:
//                     Assets.xcassets/AppIcon.appiconset, the SPM AppIcon.png,
//                     apps/web/app/icon.png, apple-icon.png, public/brand.png

import AppKit

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("usage: make-icon.swift <output.iconset> [--all]")
    exit(1)
}
let outDir = URL(fileURLWithPath: args[1])
let refreshAll = args.contains("--all")

let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()   // scripts/
    .deletingLastPathComponent()   // repo root
let sourceURL = repoRoot.appendingPathComponent("assets/brand/MaxCandela_Logo.png")

guard let source = NSImage(contentsOf: sourceURL) else {
    print("error: could not load \(sourceURL.path)")
    exit(1)
}

/// Site background — used where alpha is unwelcome (iOS home-screen icons
/// composite transparency to black, so we pick the colour deliberately).
let backdrop = NSColor(calibratedRed: 0x0a / 255, green: 0x0d / 255, blue: 0x14 / 255, alpha: 1)

/// Gradient stops for the macOS icon tile.
let tileTop = NSColor(calibratedRed: 0x1a / 255, green: 0x1f / 255, blue: 0x2e / 255, alpha: 1)
let tileBottom = NSColor(calibratedRed: 0x0a / 255, green: 0x0d / 255, blue: 0x14 / 255, alpha: 1)

/// Renders the logo square at `pixels`.
/// - `opaque`: fill the full square with the site background (iOS touch icon).
/// - `tile`: draw the macOS rounded-rect app-icon tile behind the mark. The
///   logo's laptop is near-black, so on transparency it vanishes against dark
///   wallpapers in the Dock at 16–32 px; the tile is also the macOS convention.
///   Web assets pass `false` and stay fully transparent.
/// - `inset`: breathing room so the mark isn't flush to the edge.
func render(pixels: Int, opaque: Bool = false, tile: Bool = false,
            inset: CGFloat = 0.06) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current?.imageInterpolation = .high

    let s = CGFloat(pixels)
    if opaque {
        backdrop.setFill()
        NSRect(x: 0, y: 0, width: s, height: s).fill()
    }

    // macOS icon grid: ~10% inset, continuous-corner tile at ~22.5% radius.
    var pad = s * inset
    if tile {
        let tileInset = s * 0.10
        let rect = NSRect(x: tileInset, y: tileInset,
                          width: s - tileInset * 2, height: s - tileInset * 2)
        let path = NSBezierPath(roundedRect: rect,
                                xRadius: rect.width * 0.225, yRadius: rect.width * 0.225)
        NSGradient(colors: [tileTop, tileBottom])!.draw(in: path, angle: -90)
        // Keep the mark inside the tile rather than the full square.
        pad = tileInset + rect.width * 0.08
    }

    source.draw(in: NSRect(x: pad, y: pad, width: s - pad * 2, height: s - pad * 2),
                from: .zero, operation: .sourceOver, fraction: 1.0)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func write(_ rep: NSBitmapImageRep, to url: URL) {
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
    try? data.write(to: url)
}

// --- macOS iconset (what iconutil turns into AppIcon.icns) ---------------
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
let iconSizes: [(name: String, px: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in iconSizes {
    write(render(pixels: px, tile: true), to: outDir.appendingPathComponent("\(name).png"))
}
print("wrote \(iconSizes.count) icons → \(outDir.lastPathComponent)")

guard refreshAll else { exit(0) }

// --- Checked-in app assets ----------------------------------------------
let appIconSet = repoRoot.appendingPathComponent("apps/macos/Resources/Assets.xcassets/AppIcon.appiconset")
for (name, px) in iconSizes {
    write(render(pixels: px, tile: true), to: appIconSet.appendingPathComponent("\(name).png"))
}
print("wrote Assets.xcassets/AppIcon.appiconset")

// Dialog logo (paywall / welcome popover), loaded via Bundle.module.
write(render(pixels: 512, tile: true),
      to: repoRoot.appendingPathComponent("apps/macos/Sources/MaxCandela/Resources/AppIcon.png"))
print("wrote Sources/MaxCandela/Resources/AppIcon.png")

// --- Web assets ----------------------------------------------------------
// Favicon + nav mark stay transparent so they sit on the dark site chrome.
write(render(pixels: 256), to: repoRoot.appendingPathComponent("apps/web/app/icon.png"))
write(render(pixels: 128), to: repoRoot.appendingPathComponent("apps/web/public/brand.png"))
// iOS home-screen icons render alpha as black, so choose the colour ourselves.
write(render(pixels: 180, opaque: true),
      to: repoRoot.appendingPathComponent("apps/web/app/apple-icon.png"))
print("wrote web icon.png, brand.png, apple-icon.png")
