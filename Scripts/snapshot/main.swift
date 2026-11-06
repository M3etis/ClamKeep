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

// MARK: - Views

func snapshotView(_ view: NSView, appearance: NSAppearance.Name, name: String) {
    let size = view.frame.size.height > 0 ? view.frame.size : view.fittingSize
    let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                          styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: appearance)
    let container = NSView(frame: NSRect(origin: .zero, size: size))
    container.wantsLayer = true
    container.layer?.backgroundColor = (appearance == .darkAqua ? NSColor(white: 0.17, alpha: 1) : NSColor(white: 0.97, alpha: 1)).cgColor
    view.frame = container.bounds
    container.addSubview(view)
    window.contentView = container
    container.layoutSubtreeIfNeeded()
    let rep = container.bitmapImageRepForCachingDisplay(in: container.bounds)!
    container.cacheDisplay(in: container.bounds, to: rep)
    save(rep, name)
}

func hosting<V: View>(_ view: V) -> NSView {
    let host = NSHostingView(rootView: view)
    host.frame = NSRect(origin: .zero, size: host.fittingSize)
    return host
}

let languages: [Language] = [.english, .russian, .kazakh]
let appearances: [(NSAppearance.Name, String)] = [(.aqua, "light"), (.darkAqua, "dark")]

let snap = SystemSnapshot(batteryPercent: 78, batteryIsCharging: false, batteryTimeRemaining: nil, cpuPercent: 84, ramUsedBytes: 12_000_000_000,
                          ramTotalBytes: 16_000_000_000, cpuTemperatureCelsius: 52, fanRPMs: [])

for lang in languages {
    L.current = lang
    for (appearance, suffix) in appearances {
        let states: [(String, StatusHeaderState)] = [
            ("off", StatusHeaderState(mode: .off, subtitle: L.statusHint, helperBanner: nil)),
            ("on", StatusHeaderState(mode: .on, subtitle: L.statusElapsed("01:23:45"), helperBanner: nil)),
            ("timer", StatusHeaderState(mode: .onDisplayMaySleep, subtitle: L.statusRemaining("00:14:59"), helperBanner: nil)),
            ("helper", StatusHeaderState(mode: .off, subtitle: L.statusHint, helperBanner: L.helperMissingBanner)),
        ]
        for (label, state) in states {
            let header = StatusHeaderView()
            header.reloadMetrics(snap)
            header.apply(state)
            snapshotView(header, appearance: appearance, name: "header-\(label)-\(lang.rawValue)-\(suffix).png")
        }

        let model = AppModel()
        model.helper = .installed(version: "1.4.0")
        snapshotView(hosting(GeneralPane(model: model)), appearance: appearance, name: "settings-general-\(lang.rawValue)-\(suffix).png")
        model.helper = .failed(details: "User canceled. (-128)")
        snapshotView(hosting(GeneralPane(model: model)), appearance: appearance, name: "settings-general-failed-\(lang.rawValue)-\(suffix).png")
        snapshotView(hosting(MenuBarIconPane(model: model)), appearance: appearance, name: "settings-icon-\(lang.rawValue)-\(suffix).png")
        snapshotView(hosting(AboutPane(model: model)), appearance: appearance, name: "settings-about-\(lang.rawValue)-\(suffix).png")
        model.helper = .missing
        snapshotView(hosting(HelperSetupView(model: model, onInstall: {}, onClose: {})), appearance: appearance, name: "onboarding-\(lang.rawValue)-\(suffix).png")
        model.helper = .installing
        snapshotView(hosting(HelperSetupView(model: model, onInstall: {}, onClose: {})), appearance: appearance, name: "onboarding-installing-\(lang.rawValue)-\(suffix).png")
        snapshotView(hosting(CustomTimerView(initialMinutes: 95, onStart: { _ in }, onCancel: {})), appearance: appearance, name: "timer-\(lang.rawValue)-\(suffix).png")
    }
}
