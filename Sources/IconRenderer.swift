import AppKit

enum IconStyle: String, CaseIterable {
    case moon       // shield + crescent moon
    case bolt       // shield + lightning bolt
    case eye        // shield + eye
    case coffee     // shield + coffee cup
    case plain      // plain shield

    var displayName: String {
        switch self {
        case .moon:   return "Moon"
        case .bolt:   return "Bolt"
        case .eye:    return "Eye"
        case .coffee: return "Coffee"
        case .plain:  return "Shield"
        }
    }

    var displayNameRu: String {
        switch self {
        case .moon:   return "Полумесяц"
        case .bolt:   return "Молния"
        case .eye:    return "Глаз"
        case .coffee: return "Кофе"
        case .plain:  return "Щит"
        }
    }

    var localizedName: String {
        switch L.current {
        case .english: return displayName
        case .russian: return displayNameRu
        }
    }

    static var current: IconStyle {
        get {
            if let raw = UserDefaults.standard.string(forKey: "ClamKeepIconStyle"),
               let style = IconStyle(rawValue: raw) {
                return style
            }
            return .moon
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "ClamKeepIconStyle")
        }
    }
}

enum IconRenderer {

    static func makeIcon(style: IconStyle, active: Bool) -> NSImage? {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            drawShield(active: active)
            switch style {
            case .moon:   drawMoon(active: active)
            case .bolt:   drawBolt(active: active)
            case .eye:    drawEye(active: active)
            case .coffee: drawCoffee(active: active)
            case .plain:  break
            }
            return true
        }
        image.isTemplate = false
        return image
    }

    // MARK: - Colors

    private static func shieldColor(active: Bool) -> NSColor {
        active ? NSColor(red: 0.2, green: 0.85, blue: 0.4, alpha: 1.0)
               : NSColor.white.withAlphaComponent(0.75)
    }

    private static func symbolColor(active: Bool) -> NSColor {
        active ? NSColor(white: 0.12, alpha: 1)
               : NSColor(white: 0.35, alpha: 1)
    }

    // MARK: - Shield

    private static func drawShield(active: Bool) {
        let s = NSBezierPath()
        s.move(to: CGPoint(x: 9, y: 17))
        s.curve(to: CGPoint(x: 16, y: 14),
                controlPoint1: CGPoint(x: 12, y: 17),
                controlPoint2: CGPoint(x: 16, y: 16))
        s.line(to: CGPoint(x: 16, y: 7.5))
        s.curve(to: CGPoint(x: 9, y: 1.5),
                controlPoint1: CGPoint(x: 16, y: 4.5),
                controlPoint2: CGPoint(x: 13, y: 2))
        s.curve(to: CGPoint(x: 2, y: 7.5),
                controlPoint1: CGPoint(x: 5, y: 2),
                controlPoint2: CGPoint(x: 2, y: 4.5))
        s.line(to: CGPoint(x: 2, y: 14))
        s.curve(to: CGPoint(x: 9, y: 17),
                controlPoint1: CGPoint(x: 2, y: 16),
                controlPoint2: CGPoint(x: 6, y: 17))
        s.close()
        shieldColor(active: active).setFill()
        s.fill()
    }

    // MARK: - Moon

    private static func drawMoon(active: Bool) {
        symbolColor(active: active).setFill()
        NSBezierPath(ovalIn: NSRect(x: 5.5, y: 5, width: 9, height: 9)).fill()
        shieldColor(active: active).setFill()
        NSBezierPath(ovalIn: NSRect(x: 7.2, y: 4.5, width: 9, height: 9)).fill()
    }

    // MARK: - Bolt

    private static func drawBolt(active: Bool) {
        let c = symbolColor(active: active)
        c.setFill()
        let b = NSBezierPath()
        b.move(to: CGPoint(x: 10.5, y: 14))
        b.line(to: CGPoint(x: 7.5, y: 10))
        b.line(to: CGPoint(x: 9.5, y: 10))
        b.line(to: CGPoint(x: 7.5, y: 4.5))
        b.line(to: CGPoint(x: 11, y: 9.5))
        b.line(to: CGPoint(x: 9, y: 9.5))
        b.line(to: CGPoint(x: 10.5, y: 14))
        b.close()
        b.fill()
    }

    // MARK: - Eye

    private static func drawEye(active: Bool) {
        let c = symbolColor(active: active)
        c.setStroke()
        c.setFill()

        let eye = NSBezierPath()
        eye.move(to: CGPoint(x: 3.5, y: 9.5))
        eye.curve(to: CGPoint(x: 9, y: 6),
                  controlPoint1: CGPoint(x: 5.5, y: 6.5),
                  controlPoint2: CGPoint(x: 7, y: 6))
        eye.curve(to: CGPoint(x: 14.5, y: 9.5),
                  controlPoint1: CGPoint(x: 11, y: 6),
                  controlPoint2: CGPoint(x: 12.5, y: 6.5))
        eye.curve(to: CGPoint(x: 9, y: 13),
                  controlPoint1: CGPoint(x: 12.5, y: 12.5),
                  controlPoint2: CGPoint(x: 11, y: 13))
        eye.curve(to: CGPoint(x: 3.5, y: 9.5),
                  controlPoint1: CGPoint(x: 7, y: 13),
                  controlPoint2: CGPoint(x: 5.5, y: 12.5))
        eye.close()
        eye.lineWidth = 1.0
        eye.stroke()

        let pSize: CGFloat = active ? 3.0 : 2.4
        NSBezierPath(ovalIn: NSRect(x: 9 - pSize/2, y: 9.5 - pSize/2,
                                    width: pSize, height: pSize)).fill()
    }

    // MARK: - Coffee

    private static func drawCoffee(active: Bool) {
        let c = symbolColor(active: active)
        c.setStroke()
        c.setFill()

        // Cup body
        let cup = NSBezierPath(roundedRect: NSRect(x: 4, y: 5, width: 7, height: 6),
                               xRadius: 1, yRadius: 1)
        cup.fill()

        // Handle
        let handle = NSBezierPath()
        handle.move(to: CGPoint(x: 11, y: 9.5))
        handle.curve(to: CGPoint(x: 14, y: 9.5),
                     controlPoint1: CGPoint(x: 12, y: 11),
                     controlPoint2: CGPoint(x: 14, y: 11))
        handle.curve(to: CGPoint(x: 11, y: 7),
                     controlPoint1: CGPoint(x: 14, y: 7.5),
                     controlPoint2: CGPoint(x: 12, y: 7))
        handle.lineWidth = 1.0
        handle.stroke()

        // Steam lines
        c.withAlphaComponent(0.5).setStroke()
        let steam = NSBezierPath()
        steam.move(to: CGPoint(x: 6, y: 12))
        steam.curve(to: CGPoint(x: 5.5, y: 14.5),
                    controlPoint1: CGPoint(x: 5, y: 13),
                    controlPoint2: CGPoint(x: 6.5, y: 14))
        steam.lineWidth = 0.8
        steam.stroke()

        let steam2 = NSBezierPath()
        steam2.move(to: CGPoint(x: 9, y: 12))
        steam2.curve(to: CGPoint(x: 9.5, y: 14.5),
                     controlPoint1: CGPoint(x: 10, y: 13),
                     controlPoint2: CGPoint(x: 8.5, y: 14))
        steam2.lineWidth = 0.8
        steam2.stroke()
    }
}
