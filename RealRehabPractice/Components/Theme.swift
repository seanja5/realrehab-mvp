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
    /// Standard page background — subtle cool gradient replacing the old flat gray.
    func rrPageBackground() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.978, green: 0.978, blue: 0.996), location: 0.0),
                        .init(color: Color(red: 0.942, green: 0.943, blue: 0.966), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
    }

    /// Journey map background — richer ambient depth with dual radial glows.
    func rrJourneyBackground() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                ZStack {
                    LinearGradient(
                        stops: [
                            .init(color: Color(red: 0.963, green: 0.968, blue: 1.000), location: 0.0),
                            .init(color: Color(red: 0.900, green: 0.912, blue: 0.968), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    RadialGradient(
                        colors: [Color.brandDarkBlue.opacity(0.13), Color.clear],
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: 430
                    )
                    RadialGradient(
                        colors: [Color.brandElectric.opacity(0.055), Color.clear],
                        center: .bottomLeading,
                        startRadius: 0,
                        endRadius: 320
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
    static let micro   = Animation.easeOut(duration: 0.15)
    /// State transitions: show/hide panels, expand cards
    static let state   = Animation.spring(response: 0.3, dampingFraction: 0.7)
    /// Snappy spring: matches lesson bubble timing
    static let snappy  = Animation.interactiveSpring(response: 0.2, dampingFraction: 0.7)
    /// Gentle entry: screen-level content fades and reveal animations
    static let gentle  = Animation.easeOut(duration: 0.4)
}

// MARK: - Back-compat shim so Components can use Theme.*
enum Theme {
    static let headline = Font.rrHeadline
    static let title    = Font.rrTitle
    static let body     = Font.rrBody
    static let callout  = Font.rrCallout
    static let caption  = Font.rrCaption
}
