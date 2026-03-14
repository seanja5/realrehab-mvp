import SwiftUI

// MARK: - Brand Typography
extension Font {
    static let rrHeadline   = Font.system(size: 22, weight: .bold)
    static let rrTitle      = Font.system(size: 18, weight: .semibold)
    static let rrBody       = Font.system(size: 16, weight: .regular)
    static let rrCallout    = Font.system(size: 14, weight: .regular)
    static let rrCaption    = Font.system(size: 12, weight: .regular)
}

// MARK: - Brand Spacing
enum RRSpace {
    static let pageTop: CGFloat = 20
    static let section: CGFloat = 16
    static let stack: CGFloat   = 12
}

// MARK: - Brand Background helpers
extension View {
    /// Standard page background — flat light gray used on settings, forms, detail views.
    func rrPageBackground() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                Color(red: 0.95, green: 0.95, blue: 0.95)
                    .ignoresSafeArea()
            )
    }

    /// Journey map background — subtle cool gradient with a faint brand-blue glow.
    /// More premium than the flat page background; keeps lesson bubbles clearly readable.
    func rrJourneyBackground() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                ZStack {
                    // Base: very slightly blue-tinted off-white at top fading to cool gray
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.96, green: 0.97, blue: 0.99), location: 0),
                            .init(color: Color(red: 0.91, green: 0.92, blue: 0.95), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    // Subtle ambient glow anchored top-right using brand blue at very low opacity
                    RadialGradient(
                        colors: [Color(red: 0.2, green: 0.4, blue: 0.8).opacity(0.07), Color.clear],
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: 420
                    )
                }
                .ignoresSafeArea()
            )
    }
    
    /// Dismisses keyboard when tapping outside text fields/editors
    func dismissKeyboardOnTap() -> some View {
        self.onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}
// MARK: - Animation Constants
enum RRAnimation {
    /// Fast micro-interactions: button press, icon scale
    static let micro = Animation.easeOut(duration: 0.15)
    /// State transitions: show/hide panels, expand cards
    static let state = Animation.spring(response: 0.3, dampingFraction: 0.7)
    /// Snappy spring: matches lesson bubble timing
    static let snappy = Animation.interactiveSpring(response: 0.2, dampingFraction: 0.7)
}

// MARK: - Back-compat shim so Components can use Theme.*
enum Theme {
    static let headline = Font.rrHeadline
    static let title    = Font.rrTitle
    static let body     = Font.rrBody
    static let callout  = Font.rrCallout
    static let caption  = Font.rrCaption
}
