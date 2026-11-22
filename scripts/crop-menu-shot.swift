// Crop a real menu capture to the menu itself, for the website's hero.
//
//   swift scripts/crop-menu-shot.swift <raw capture.png> <out.png>
//
// The raw captures come from scripts/make-app-screenshots.sh: one real menu on
// an opaque backdrop, with a margin left for the menu's shadow. The website
// wants the menu alone, so this finds the menu's 1-px border (the only thing
// clearly lighter than the backdrop around it), crops to it, and makes
// everything outside the rounded corners transparent. The page puts its own
// shadow back with CSS.
import AppKit

let args = CommandLine.arguments
guard args.count == 3,
      let source = NSImage(contentsOfFile: args[1]),
      let cg = source.cgImage(forProposedRect: nil, context: nil, hints: nil)
else {
    FileHandle.standardError.write("usage: crop-menu-shot.swift <in.png> <out.png>\n".data(using: .utf8)!)
    exit(1)
}

let width = cg.width, height = cg.height
var pixels = [UInt8](repeating: 0, count: width * height * 4)
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width * 4, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

func luma(_ x: Int, _ y: Int) -> Int {
    let i = (y * width + x) * 4
    return (Int(pixels[i]) * 3 + Int(pixels[i + 1]) * 6 + Int(pixels[i + 2])) / 10
}

// The backdrop is whatever the top-left corner is; the border is well above it.
let backdrop = luma(2, 2)
let threshold = backdrop + 25
var minX = width, minY = height, maxX = -1, maxY = -1
for y in 0..<height {
    for x in 0..<width where luma(x, y) > threshold {
        minX = min(minX, x); maxX = max(maxX, x)
        minY = min(minY, y); maxY = max(maxY, y)
    }
}
guard maxX > minX, maxY > minY else {
    FileHandle.standardError.write("no menu border found\n".data(using: .utf8)!)
    exit(1)
}

// Corner radius: how far in from the left the border starts on the top edge.
var radius = 0
for x in minX...maxX where luma(x, minY) > threshold { radius = x - minX; break }
radius = max(radius, 8)

let cropW = maxX - minX + 1, cropH = maxY - minY + 1
var out = [UInt8](repeating: 0, count: cropW * cropH * 4)
let r = Double(radius)
for y in 0..<cropH {
    for x in 0..<cropW {
        // Distance outside the rounded rectangle, for a 1-px antialiased edge.
        let cx = Double(x) + 0.5, cy = Double(y) + 0.5
        let dx = max(r - cx, cx - (Double(cropW) - r), 0)
        let dy = max(r - cy, cy - (Double(cropH) - r), 0)
        let inCorner = dx > 0 && dy > 0
        let coverage = inCorner ? max(0, min(1, r - (dx * dx + dy * dy).squareRoot() + 0.5)) : 1
        let si = ((y + minY) * width + (x + minX)) * 4
        let oi = (y * cropW + x) * 4
        for c in 0..<4 { out[oi + c] = UInt8(Double(pixels[si + c]) * coverage) }
    }
}

let outCtx = CGContext(data: &out, width: cropW, height: cropH, bitsPerComponent: 8,
                       bytesPerRow: cropW * 4, space: space,
                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let rep = NSBitmapImageRep(cgImage: outCtx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
print("menu \(cropW)x\(cropH) px, corner radius \(radius) px")
