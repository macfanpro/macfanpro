#!/usr/bin/env swift
// Renders the social preview images (1280x640) from the app icon and a menu screenshot:
//   swift Scripts/generate-social-preview.swift docs/images/icon.png docs/images/menu-bar-en.png docs/images/social-preview.png en
//   swift Scripts/generate-social-preview.swift docs/images/icon.png docs/images/menu-bar-zh-CN.png docs/images/social-preview-zh-CN.png
import AppKit
let args = CommandLine.arguments
let icon = NSImage(contentsOfFile: args[1])!, shot = NSImage(contentsOfFile: args[2])!, out = args[3]
let english = args.count > 4 && args[4] == "en"
let W: CGFloat = 1280, H: CGFloat = 640
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor { NSColor(calibratedRed: r/255, green: g/255, blue: b/255, alpha: a) }
let cyan = rgb(0, 229, 255), blue = rgb(41, 121, 255), violet = rgb(124, 77, 255)

// Deep navy base.
NSGradient(starting: rgb(4, 8, 20), ending: rgb(10, 20, 44))!.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -35)
// Soft glows: cyan behind the panel, violet at the lower left.
func glow(_ c: NSColor, _ center: NSPoint, _ r: CGFloat) {
    NSGradient(colors: [c, c.withAlphaComponent(0)])!.draw(fromCenter: center, radius: 0, toCenter: center, radius: r, options: [])
}
glow(cyan.withAlphaComponent(0.22), NSPoint(x: 1060, y: 330), 380)
glow(violet.withAlphaComponent(0.18), NSPoint(x: 120, y: 60), 420)
// Faint grid.
let grid = NSBezierPath()
for x in stride(from: CGFloat(0), through: W, by: 40) { grid.move(to: NSPoint(x: x, y: 0)); grid.line(to: NSPoint(x: x, y: H)) }
for y in stride(from: CGFloat(0), through: H, by: 40) { grid.move(to: NSPoint(x: 0, y: y)); grid.line(to: NSPoint(x: W, y: y)) }
grid.lineWidth = 1; cyan.withAlphaComponent(0.05).setStroke(); grid.stroke()

func text(_ s: String, _ font: NSFont, _ color: NSColor, _ x: CGFloat, _ y: CGFloat, kern: CGFloat = 0) {
    NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: color, .kern: kern]).draw(at: NSPoint(x: x, y: y))
}

// Keep the project icon sharp at social-preview size.
NSGraphicsContext.current?.imageInterpolation = .high
icon.draw(in: NSRect(x: 72, y: 430, width: 120, height: 120))
text("MacFanPro", .systemFont(ofSize: 74, weight: .bold), .white, 214, 440)

// Gradient accent line under the title.
NSGradient(colors: [cyan, blue, violet.withAlphaComponent(0)])!.draw(in: NSRect(x: 72, y: 402, width: 460, height: 3), angle: 0)

text(english ? "Fan control for Apple Silicon Macs" : "Apple Silicon Mac 风扇控制", .systemFont(ofSize: english ? 38 : 42, weight: .semibold), .white, 72, 326, kern: english ? 0 : 1)
let lines = english ? ["Free & open source · MIT", "Menu bar app + CLI · One-click updates", "M1–M5 · macOS 14+ · 18 languages"]
    : ["免费开源 · MIT 协议", "菜单栏应用 + 命令行 · 一键更新", "M1–M5 · macOS 14+ · 18 种语言"]
for (i, line) in lines.enumerated() {
    let y = CGFloat(262 - i * 58)
    // Glowing square marker.
    let dot = NSShadow(); dot.shadowBlurRadius = 10; dot.shadowColor = cyan; dot.shadowOffset = .zero
    NSGraphicsContext.saveGraphicsState(); dot.set(); cyan.setFill()
    NSBezierPath(roundedRect: NSRect(x: 78, y: y + 12, width: 12, height: 12), xRadius: 3, yRadius: 3).fill()
    NSGraphicsContext.restoreGraphicsState()
    text(line, .systemFont(ofSize: 30, weight: .medium), rgb(200, 220, 240), 110, y)
}
text("github.com/macfanpro/macfanpro", .monospacedSystemFont(ofSize: 22, weight: .regular), cyan.withAlphaComponent(0.75), 72, 40)

// Menu screenshot with a cyan edge glow.
let h: CGFloat = 588, w = shot.size.width / shot.size.height * h
let frame = NSRect(x: W - w - 72, y: 26, width: w, height: h)
let sh = NSShadow(); sh.shadowBlurRadius = 40; sh.shadowColor = cyan.withAlphaComponent(0.35); sh.shadowOffset = .zero
NSGraphicsContext.saveGraphicsState(); sh.set()
NSColor.black.setFill(); NSBezierPath(roundedRect: frame, xRadius: 14, yRadius: 14).fill()
NSGraphicsContext.restoreGraphicsState()
NSGraphicsContext.saveGraphicsState()
NSBezierPath(roundedRect: frame, xRadius: 14, yRadius: 14).addClip()
shot.draw(in: frame)
NSGraphicsContext.restoreGraphicsState()
let border = NSBezierPath(roundedRect: frame.insetBy(dx: 0.5, dy: 0.5), xRadius: 14, yRadius: 14)
border.lineWidth = 1; cyan.withAlphaComponent(0.5).setStroke(); border.stroke()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
