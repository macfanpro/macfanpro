#!/usr/bin/env swift
//
// Generates MacFanPro app icon from SF Symbol
//

import AppKit

func renderIcon(size: Int, scale: Int = 1) -> NSImage {
    let px = size * scale
    let image = NSImage(size: NSSize(width: px, height: px))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: px, height: px)

    // Background: deep navy rounded rectangle with a thin cyan edge
    let cornerRadius = CGFloat(px) * 0.22
    let path = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: cornerRadius, yRadius: cornerRadius)

    let cyan = NSColor(red: 0.0, green: 0.90, blue: 1.0, alpha: 1.0)
    let blue = NSColor(red: 0.16, green: 0.47, blue: 1.0, alpha: 1.0)
    let violet = NSColor(red: 0.49, green: 0.30, blue: 1.0, alpha: 1.0)

    let gradient = NSGradient(colors: [
        NSColor(red: 0.06, green: 0.12, blue: 0.24, alpha: 1.0),
        NSColor(red: 0.02, green: 0.04, blue: 0.09, alpha: 1.0),
    ])!
    gradient.draw(in: path, angle: -90)
    // The edge only reads at larger sizes; at 16–32 px it would outweigh the fan.
    if px >= 64 {
        path.lineWidth = CGFloat(px) / 128
        cyan.withAlphaComponent(0.55).setStroke()
        path.stroke()
    }

    // Fan symbol with a cyan → blue → violet gradient and a soft glow
    let symbolSize = CGFloat(px) * 0.55
    let config = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .medium)
    if let symbol = NSImage(systemSymbolName: "fan.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(config)
    {
        let symbolRect = symbol.size
        let x = (CGFloat(px) - symbolRect.width) / 2
        let y = (CGFloat(px) - symbolRect.height) / 2 + CGFloat(px) * 0.02

        let tinted = NSImage(size: symbolRect)
        tinted.lockFocus()
        symbol.draw(in: NSRect(origin: .zero, size: symbolRect))
        NSGraphicsContext.current?.compositingOperation = .sourceAtop
        NSGradient(colors: [cyan, blue, violet])!.draw(in: NSRect(origin: .zero, size: symbolRect), angle: -45)
        tinted.unlockFocus()

        let glow = NSShadow()
        glow.shadowBlurRadius = CGFloat(px) * 0.06
        glow.shadowColor = cyan.withAlphaComponent(0.6)
        glow.shadowOffset = .zero
        NSGraphicsContext.saveGraphicsState()
        glow.set()
        tinted.draw(in: NSRect(x: x, y: y, width: symbolRect.width, height: symbolRect.height))
        NSGraphicsContext.restoreGraphicsState()
    }

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:])
    else { return }
    try! png.write(to: URL(fileURLWithPath: path))
}

// Create iconset directory
let iconsetPath = "MacFanPro.iconset"
try? FileManager.default.removeItem(atPath: iconsetPath)
try! FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)

// Generate all required sizes
let sizes = [16, 32, 128, 256, 512]
for size in sizes {
    savePNG(renderIcon(size: size), to: "\(iconsetPath)/icon_\(size)x\(size).png")
    savePNG(renderIcon(size: size, scale: 2), to: "\(iconsetPath)/icon_\(size)x\(size)@2x.png")
}

print("Generated iconset at \(iconsetPath)")
