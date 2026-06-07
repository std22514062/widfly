import SwiftUI
import UIKit

/// Shared design tokens for the Widfly iOS app.
/// Kept in sync with the widget extension's palette so the two surfaces
/// feel like one product.
enum Theme {
    /// Deep navy (#0B2545) — app background, matches widget container and app icon.
    static let background = Color(red: 0.043, green: 0.145, blue: 0.271)
    /// UIKit twin of `background`, used for UIWindow-level paint so the
    /// status bar / home indicator safe areas fill with navy instead of black.
    static let backgroundUIColor = UIColor(red: 0.043, green: 0.145, blue: 0.271, alpha: 1)
    /// Amber accent (#F5C518) — matches app icon tick and price-rise indicator.
    static let amber = Color(red: 0.961, green: 0.773, blue: 0.094)
    /// Green for price drops.
    static let dropGreen = Color(red: 0.40, green: 0.85, blue: 0.55)

    /// Frosted glass surface fill for cards.
    static let cardFill = Color.white.opacity(0.08)
    /// Frosted glass surface stroke for cards.
    static let cardStroke = Color.white.opacity(0.20)

    /// Muted white for secondary text (date, duration, "updated" labels).
    static let mutedText = Color.white.opacity(0.65)

    static let cardCornerRadius: CGFloat = 14
}

extension Font {
    /// Heavy proportional sans for IATA codes / large headings.
    static func iata(size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .default)
    }

    /// Heavy proportional sans for prices, with tabular digits for alignment.
    static func price(size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .default).monospacedDigit()
    }
}
