#!/usr/bin/env swift
// Renders the social/SEO share image og.png (1200×630) from the single source
// logo (assets/brand/MaxCandela_Logo.png) on a solid site-coloured background.
//
// The background is deliberate, not laziness: social cards render transparent
// PNGs unpredictably (some composite on white, some on black), so the share
// image is the one place the mark must NOT be transparent.
//
// Usage: swift scripts/make-hero.swift <output-dir>

import AppKit

guard CommandLine.arguments.count == 2 else {
    print("usage: make-hero.swift <output-dir>")
    exit(1)
}
let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let sourceURL = repoRoot.appendingPathComponent("assets/brand/MaxCandela_Logo.png")

guard let logo = NSImage(contentsOf: sourceURL) else {
    print("error: could not load \(sourceURL.path)")
    exit(1)
}

let ogW: CGFloat = 1200
let ogH: CGFloat = 630

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(ogW), pixelsHigh: Int(ogH),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current?.imageInterpolation = .high

// Solid site background (#0b0d10).
NSColor(calibratedRed: 0x0b / 255, green: 0x0d / 255, blue: 0x10 / 255, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: ogW, height: ogH).fill()

// Centre the logo, sized to the card height with margin so it reads as a
// product mark rather than a full-bleed image.
let side = ogH * 0.82
logo.draw(in: NSRect(x: (ogW - side) / 2, y: (ogH - side) / 2, width: side, height: side),
          from: .zero, operation: .sourceOver, fraction: 1.0)

NSGraphicsContext.restoreGraphicsState()

try rep.representation(using: .png, properties: [:])!
    .write(to: outDir.appendingPathComponent("og.png"))
print("wrote og.png (1200×630)")
