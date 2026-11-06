// Dev-only: renders UI pieces to PNG for visual review.
// Run: Scripts/snapshot.sh  →  build/snapshots/*.png
import AppKit
import SwiftUI

let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/snapshots")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
_ = NSApplication.shared

func save(_ rep: NSBitmapImageRep, _ name: String) {
    let url = outDir.appendingPathComponent(name)
    try? rep.representation(using: .png, properties: [:])?.write(to: url)
    print("wrote", url.path)
}

func render(size: NSSize, scale: CGFloat = 2, appearance: NSAppearance.Name, draw: (NSRect) -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance { draw(NSRect(origin: .zero, size: size)) }
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

/// Draws an image the way the menu bar would: templates get the bar's ink color.
func drawGlyph(_ image: NSImage, in rect: NSRect, ink: NSColor) {
    guard image.isTemplate else { image.draw(in: rect); return }
    let tinted = NSImage(size: image.size, flipped: false) { r in
        image.draw(in: r)
        ink.set()
        r.fill(using: .sourceAtop)
        return true
    }
    tinted.draw(in: rect)
}

func snapshotMenuBarIcons() {
    let states: [MenuBarIconState] = [.inactive, .active, .activeDisplaySleepAllowed]
    for (appearance, bar, ink, suffix) in [(NSAppearance.Name.aqua, NSColor(white: 0.93, alpha: 1), NSColor.black, "light"),
                                           (.darkAqua, NSColor(white: 0.16, alpha: 1), NSColor.white, "dark")] {
        for tinted in [false, true] {
            let cell: CGFloat = 30
            let size = NSSize(width: cell * CGFloat(states.count) + 8, height: cell * CGFloat(IconStyle.allCases.count) + 8)
            let rep = render(size: size, scale: 4, appearance: appearance) { rect in
                bar.setFill(); rect.fill()
                for (row, style) in IconStyle.allCases.enumerated() {
                    for (col, state) in states.enumerated() {
                        let img = MenuBarIcon.image(style: style, state: state, tinted: tinted)
                        let r = NSRect(x: 4 + CGFloat(col) * cell + 6, y: size.height - 4 - CGFloat(row + 1) * cell + 6, width: 18, height: 18)
                        drawGlyph(img, in: r, ink: ink)
                    }
                }
            }
            save(rep, "menubar-icons-\(suffix)\(tinted ? "-tinted" : "").png")
        }
    }
}

snapshotMenuBarIcons()
