import Combine
import SwiftUI

/// Manages the app-wide dark mode preference.
/// Source of truth for `preferredColorScheme` at the root of the app.
/// - UserDefaults: instant read on launch (no flicker)
/// - Supabase: persisted via AuthService.setDarkModeEnabled() called from settings
@MainActor
final class AppThemeManager: ObservableObject {
    private static let userDefaultsKey = "dark_mode_enabled"

    @Published var isDarkMode: Bool {
        didSet {
            UserDefaults.standard.set(isDarkMode, forKey: Self.userDefaultsKey)
        }
    }

    init() {
        isDarkMode = UserDefaults.standard.bool(forKey: Self.userDefaultsKey)
    }

    /// Sync from a freshly loaded Profile (called after login/session bootstrap).
    func syncFromProfile(_ profile: Profile) {
        let remote = profile.dark_mode_enabled ?? false
        if isDarkMode != remote {
            isDarkMode = remote
        }
    }
}
