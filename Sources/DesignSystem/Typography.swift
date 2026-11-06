import AppKit
import SwiftUI

/// Type scale on SF Pro. Body is the 13-pt macOS default; nothing goes below 10 pt.
/// Text styles (not fixed sizes) are used so text follows the system size setting.
extension DS {
    enum Typography {
        // SwiftUI
        static let title = Font.title3.weight(.semibold)          // 15
        static let headline = Font.headline                        // 13 semibold
        static let body = Font.body                                // 13
        static let callout = Font.callout                          // 12
        static let caption = Font.subheadline                      // 11
        static let footnote = Font.footnote                        // 10 — minimum
        static let numeric = Font.body.monospacedDigit()           // timers, metrics
        static let technical = Font.system(.callout, design: .monospaced)

        // AppKit (custom menu views)
        static var menu: NSFont { .menuFont(ofSize: 0) }
        static var menuHeadline: NSFont { .systemFont(ofSize: NSFont.systemFontSize, weight: .semibold) }
        static var menuCaption: NSFont { .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular) }
        static var metricValue: NSFont { .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .semibold) }
        static var metricValueCompact: NSFont { .monospacedDigitSystemFont(ofSize: 11, weight: .semibold) }
        static var metricLabel: NSFont { .systemFont(ofSize: 10, weight: .medium) }
    }
}
