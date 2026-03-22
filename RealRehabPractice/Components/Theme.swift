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

// MARK: - Page Background Modifier
private struct RRPageBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                Group {
                    if colorScheme == .dark {
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 0.07, green: 0.08, blue: 0.12), location: 0.0),
                                .init(color: Color(red: 0.06, green: 0.07, blue: 0.10), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    } else {
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 0.978, green: 0.978, blue: 0.996), location: 0.0),
                                .init(color: Color(red: 0.942, green: 0.943, blue: 0.966), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
                .ignoresSafeArea()
            )
    }
}

// MARK: - Journey Background Modifier
private struct RRJourneyBackgroundModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                ZStack {
                    if colorScheme == .dark {
                        LinearGradient(
                            stops: [
                                .init(color: Color(red: 0.07, green: 0.08, blue: 0.14), location: 0.0),
                                .init(color: Color(red: 0.05, green: 0.06, blue: 0.12), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        RadialGradient(
                            colors: [Color.brandElectric.opacity(0.10), Color.clear],
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: 430
                        )
                        RadialGradient(
                            colors: [Color.brandDarkBlue.opacity(0.15), Color.clear],
                            center: .bottomLeading,
                            startRadius: 0,
                            endRadius: 320
                        )
                    } else {
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
                }
                .ignoresSafeArea()
            )
    }
}

// MARK: - Brand Background helpers
extension View {
    /// Standard page background — adapts to light / dark mode.
    func rrPageBackground() -> some View {
        modifier(RRPageBackgroundModifier())
    }

    /// Journey map background — richer ambient depth with dual radial glows. Adapts to dark mode.
    func rrJourneyBackground() -> some View {
        modifier(RRJourneyBackgroundModifier())
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
