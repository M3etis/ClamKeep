import AppKit
import SwiftUI

/// ClamKeep design system. Every value here is either a layout constant or a
/// thin alias over a dynamic system value, so light/dark mode, the system
/// accent color, Increase Contrast and Reduce Motion keep working for free.
enum DS {

    /// 4-pt based spacing scale.
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        /// Horizontal inset that lines custom menu views up with standard menu item titles.
        static let menuInset: CGFloat = 14
    }

    enum Radius {
        static let small: CGFloat = 4
        static let medium: CGFloat = 6
        static let large: CGFloat = 10
        static let xLarge: CGFloat = 14
    }

    /// Hairline strokes instead of drop shadows: windows and menus already get
    /// their elevation from the system, content inside them stays flat.
    enum Elevation {
        static let hairline: CGFloat = 1
        static let selectionRing: CGFloat = 2
    }

    enum Opacity {
        static let disabled: Double = 0.35
        static let secondary: Double = 0.6
        static let subtleFill: Double = 0.08
        static let tintedFill: Double = 0.12
        static let tintedStroke: Double = 0.28
    }

    enum Motion {
        static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
        static var fast: Double { reduceMotion ? 0 : 0.12 }
        static var standard: Double { reduceMotion ? 0 : 0.2 }
        static var slow: Double { reduceMotion ? 0 : 0.3 }

        /// Short ease-out animation, or none when Reduce Motion is on.
        static func animation(_ duration: Double = standard) -> Animation? {
            reduceMotion ? nil : .easeOut(duration: duration)
        }
    }

    enum Size {
        static let menuHeaderWidth: CGFloat = 340
        static let menuBarGlyph: CGFloat = 18
        static let statusDot: CGFloat = 8
        static let metricIcon: CGFloat = 15
        static let iconTile: CGFloat = 104
        static let settingsWidth: CGFloat = 480
        static let appIconLarge: CGFloat = 96
        static let appIconMedium: CGFloat = 64
    }
}
