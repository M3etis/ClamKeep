import AppKit
import SwiftUI

/// Semantic colors. All of them resolve to dynamic system colors, so they
/// adapt to light/dark mode, the user's accent color and Increase Contrast.
extension DS {
    enum Palette {
        static var background: NSColor { .windowBackgroundColor }
        static var surface: NSColor { .controlBackgroundColor }
        static var elevatedSurface: NSColor { .underPageBackgroundColor }

        static var textPrimary: NSColor { .labelColor }
        static var textSecondary: NSColor { .secondaryLabelColor }
        static var textTertiary: NSColor { .tertiaryLabelColor }
        static var separator: NSColor { .separatorColor }

        static var accent: NSColor { .controlAccentColor }
        static var success: NSColor { .systemGreen }
        static var warning: NSColor { .systemOrange }
        static var danger: NSColor { .systemRed }
        static var inactive: NSColor { .systemGray }
    }
}

extension Color {
    static var dsBackground: Color { Color(nsColor: DS.Palette.background) }
    static var dsSurface: Color { Color(nsColor: DS.Palette.surface) }
    static var dsElevatedSurface: Color { Color(nsColor: DS.Palette.elevatedSurface) }
    static var dsTextPrimary: Color { Color(nsColor: DS.Palette.textPrimary) }
    static var dsTextSecondary: Color { Color(nsColor: DS.Palette.textSecondary) }
    static var dsTextTertiary: Color { Color(nsColor: DS.Palette.textTertiary) }
    static var dsSeparator: Color { Color(nsColor: DS.Palette.separator) }
    static var dsAccent: Color { Color(nsColor: DS.Palette.accent) }
    static var dsSuccess: Color { Color(nsColor: DS.Palette.success) }
    static var dsWarning: Color { Color(nsColor: DS.Palette.warning) }
    static var dsDanger: Color { Color(nsColor: DS.Palette.danger) }
}
