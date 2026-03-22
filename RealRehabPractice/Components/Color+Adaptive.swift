import SwiftUI
import UIKit

// MARK: - Adaptive Semantic Colors
// These colors automatically switch between light and dark variants based
// on the current interface style. Defined via UIColor dynamic provider so
// they work anywhere without needing @Environment(\.colorScheme).

extension Color {
    /// Card / sheet surface. Light: white. Dark: deep navy-slate.
    static let rrSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.14, green: 0.16, blue: 0.24, alpha: 1)
            : .white
    })

    /// Secondary surface (nested cards, filter chips). Slightly lighter than rrSurface in dark.
    static let rrSurfaceSecondary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.18, green: 0.20, blue: 0.28, alpha: 1)
            : UIColor(white: 0.96, alpha: 1)
    })

    /// Skeleton / shimmer placeholder fill.
    static let rrSkeleton = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.20, green: 0.22, blue: 0.30, alpha: 1)
            : UIColor(white: 0.88, alpha: 1)
    })

    /// Subtle border / divider stroke.
    static let rrBorder = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.10)
            : UIColor(white: 0, alpha: 0.08)
    })

    /// Section header label (e.g. "ACCOUNT", "NOTIFICATIONS").
    static let rrSectionLabel = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.55, green: 0.62, blue: 0.75, alpha: 1)
            : UIColor(red: 0.50, green: 0.53, blue: 0.62, alpha: 1)
    })

    /// Text field / input background.
    static let rrInputBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.18, green: 0.20, blue: 0.28, alpha: 1)
            : .white
    })
}
