import AppKit

/// Menu bar icon styles. Raw values are persisted under `ClamKeepIconStyle`
/// and must stay stable — existing installs keep their choice.
enum IconStyle: String, CaseIterable {
    case lid        // closed laptop with a live seam (matches the app icon)
    case moon
    case bolt
    case eye
    case coffee
    case plain      // shield

    private static let key = "ClamKeepIconStyle"

    var localizedName: String {
        switch self {
        case .lid:    return L.iconLid
        case .moon:   return L.iconMoon
        case .bolt:   return L.iconBolt
        case .eye:    return L.iconEye
        case .coffee: return L.iconCoffee
        case .plain:  return L.iconShield
        }
    }

    /// SF Symbol base name; `nil` for the custom-drawn `lid` glyph.
    fileprivate var symbolName: String? {
        switch self {
        case .lid:    return nil
        case .moon:   return "moon"
        case .bolt:   return "bolt"
        case .eye:    return "eye"
        case .coffee: return "cup.and.saucer"
        case .plain:  return "shield"
        }
    }

    static var current: IconStyle {
        get {
            if let raw = UserDefaults.standard.string(forKey: key),
               let style = IconStyle(rawValue: raw) {
                return style
            }
            return .lid
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }
}

enum MenuBarIconState {
    case inactive
    case active
    /// Wake Mode is on, but the display is allowed to sleep.
    case activeDisplaySleepAllowed
}

/// Renders the status item glyph.
///
/// Default: a monochrome template image (outline = off, filled = on), so it follows
/// the menu bar appearance, highlight and Increase Contrast like system extras.
/// Optional: green / orange tint while active (`ClamKeepTintMenuBarIcon`).
enum MenuBarIcon {
    static let tintKey = "ClamKeepTintMenuBarIcon"

    static var tintWhenActive: Bool {
        get { UserDefaults.standard.bool(forKey: tintKey) }
        set { UserDefaults.standard.set(newValue, forKey: tintKey) }
    }

    /// First launch of the redesigned build. Upgraders keep the look they had
    /// (colored icon, moon); fresh installs get the native template look and `lid`.
    static func migrateDefaults() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: tintKey) == nil else { return }
        let previousKeys = ["ClamKeepIconStyle", "ClamKeepLanguage", "ClamKeepAllowDisplaySleep",
                            "ClamKeepPreventDisplaySleep", "ClamKeepDownloadMonitor"]
        let isUpgrade = previousKeys.contains { defaults.object(forKey: $0) != nil }
        defaults.set(isUpgrade, forKey: tintKey)
        if defaults.object(forKey: "ClamKeepIconStyle") == nil {
            IconStyle.current = isUpgrade ? .moon : .lid
        }
    }

    static func image(style: IconStyle,
                      state: MenuBarIconState,
                      tinted: Bool = MenuBarIcon.tintWhenActive) -> NSImage {
        let tint: NSColor? = {
            guard tinted else { return nil }
            switch state {
            case .inactive: return nil
            case .active: return .systemGreen
            case .activeDisplaySleepAllowed: return .systemOrange
            }
        }()
        let filled = state != .inactive
        let side = DS.Size.menuBarGlyph

        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let ink = tint ?? .black
            if let symbol = style.symbolName {
                drawSymbol(filled ? symbol + ".fill" : symbol, ink: ink, tinted: tint != nil, in: rect)
            } else {
                drawLid(filled: filled, ink: ink)
            }
            if state == .activeDisplaySleepAllowed {
                drawDisplaySleepBadge(ink: ink, in: rect)
            }
            return true
        }
        image.isTemplate = tint == nil
        image.accessibilityDescription = accessibilityDescription(for: state)
        return image
    }

    static func accessibilityDescription(for state: MenuBarIconState) -> String {
        switch state {
        case .inactive: return "ClamKeep — \(L.statusSleepingNormally)"
        case .active: return "ClamKeep — \(L.statusAwake)"
        case .activeDisplaySleepAllowed: return "ClamKeep — \(L.statusAwake), \(L.allowDisplaySleep)"
        }
    }

    // MARK: - Drawing

    private static func drawSymbol(_ name: String, ink: NSColor, tinted: Bool, in rect: NSRect) {
        var config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        if tinted {
            config = config.applying(NSImage.SymbolConfiguration(paletteColors: [ink]))
        }
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(config) else { return }
        let size = symbol.size
        let origin = NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2)
        symbol.draw(in: NSRect(origin: origin, size: size))
    }

    /// Closed MacBook seen from the front and slightly above: the lid's top
    /// surface in perspective, a seam, then the front edge of the base.
    /// Same 1.4-pt stroke as SF Symbols at this size.
    private static func drawLid(filled: Bool, ink: NSColor) {
        let stroke: CGFloat = 1.4
        let lid = NSBezierPath()
        lid.move(to: NSPoint(x: 4.6, y: 14.2))
        lid.line(to: NSPoint(x: 13.4, y: 14.2))
        lid.curve(to: NSPoint(x: 14.6, y: 13.4), controlPoint1: NSPoint(x: 14.0, y: 14.2), controlPoint2: NSPoint(x: 14.4, y: 13.9))
        lid.line(to: NSPoint(x: 16.3, y: 9.2))
        lid.curve(to: NSPoint(x: 15.4, y: 8.0), controlPoint1: NSPoint(x: 16.5, y: 8.6), controlPoint2: NSPoint(x: 16.1, y: 8.0))
        lid.line(to: NSPoint(x: 2.6, y: 8.0))
        lid.curve(to: NSPoint(x: 1.7, y: 9.2), controlPoint1: NSPoint(x: 1.9, y: 8.0), controlPoint2: NSPoint(x: 1.5, y: 8.6))
        lid.line(to: NSPoint(x: 3.4, y: 13.4))
        lid.curve(to: NSPoint(x: 4.6, y: 14.2), controlPoint1: NSPoint(x: 3.6, y: 13.9), controlPoint2: NSPoint(x: 4.0, y: 14.2))
        lid.close()

        let base = NSBezierPath(roundedRect: NSRect(x: 1, y: 3.6, width: 16, height: 2.6), xRadius: 1.3, yRadius: 1.3)

        ink.set()
        for path in [lid, base] {
            if filled {
                path.fill()
            } else {
                path.lineWidth = stroke
                path.lineJoinStyle = .round
                path.stroke()
            }
        }
    }

    /// Small ring in the corner: "the screen may sleep".
    private static func drawDisplaySleepBadge(ink: NSColor, in rect: NSRect) {
        let badge = NSRect(x: rect.maxX - 7, y: rect.minY, width: 7, height: 7)
        NSGraphicsContext.current?.compositingOperation = .clear
        NSBezierPath(ovalIn: badge).fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
        ink.set()
        let ring = NSBezierPath(ovalIn: badge.insetBy(dx: 1.4, dy: 1.4))
        ring.lineWidth = 1.3
        ring.stroke()
    }
}
