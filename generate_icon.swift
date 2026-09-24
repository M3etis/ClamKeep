import AppKit
import Foundation

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))

image.lockFocus()

let ctx = NSGraphicsContext.current!
ctx.cgContext.setAllowsAntialiasing(true)
ctx.cgContext.setShouldAntialias(true)

// Background
let rect = CGRect(x: 0, y: 0, width: size, height: size)
let cornerRadius: CGFloat = 220
let bgPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
bgPath.addClip()

// Gradient - dark blue
let gradient = NSGradient(colors: [
    NSColor(red: 0.12, green: 0.30, blue: 0.65, alpha: 1.0),
    NSColor(red: 0.08, green: 0.45, blue: 0.55, alpha: 1.0)
])!
gradient.draw(in: rect, angle: 135)

// Shield - centered, large
let cx: CGFloat = 512
let shieldW: CGFloat = 340
let shieldTop: CGFloat = 770
let shieldBottom: CGFloat = 250
let shieldCurveTop: CGFloat = 660

let shield = NSBezierPath()
shield.move(to: CGPoint(x: cx, y: shieldTop))
shield.curve(to: CGPoint(x: cx + shieldW, y: shieldCurveTop),
             controlPoint1: CGPoint(x: cx + shieldW * 0.35, y: shieldTop),
             controlPoint2: CGPoint(x: cx + shieldW, y: shieldTop))
shield.line(to: CGPoint(x: cx + shieldW, y: 420))
shield.curve(to: CGPoint(x: cx, y: shieldBottom),
             controlPoint1: CGPoint(x: cx + shieldW, y: 320),
             controlPoint2: CGPoint(x: cx + shieldW * 0.5, y: 270))
shield.curve(to: CGPoint(x: cx - shieldW, y: 420),
             controlPoint1: CGPoint(x: cx - shieldW * 0.5, y: 270),
             controlPoint2: CGPoint(x: cx - shieldW, y: 320))
shield.line(to: CGPoint(x: cx - shieldW, y: shieldCurveTop))
shield.curve(to: CGPoint(x: cx, y: shieldTop),
             controlPoint1: CGPoint(x: cx - shieldW, y: shieldTop),
             controlPoint2: CGPoint(x: cx - shieldW * 0.35, y: shieldTop))
shield.close()

NSColor.white.withAlphaComponent(0.95).setFill()
shield.fill()

// Crescent moon inside shield
// Outer circle (full moon)
NSColor(red: 0.12, green: 0.30, blue: 0.65, alpha: 1.0).setFill()
let outerMoon = NSBezierPath(ovalIn: NSRect(x: cx - 140, y: 380, width: 280, height: 280))
outerMoon.fill()

// Inner circle (cutout) - shifted right to create crescent
NSColor.white.setFill()
let innerMoon = NSBezierPath(ovalIn: NSRect(x: cx - 60, y: 360, width: 280, height: 280))
innerMoon.fill()

image.unlockFocus()

// Save
let tiffData = image.tiffRepresentation!
let bitmapRep = NSBitmapImageRep(data: tiffData)!
let pngData = bitmapRep.representation(using: .png, properties: [:])!

let pngPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024x1024.png"
try! pngData.write(to: URL(fileURLWithPath: pngPath))
print("Icon saved to \(pngPath)")
