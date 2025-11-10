import SwiftUI

struct SafeAreaDebugOverlay: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            Color.red.opacity(0.03)
                .ignoresSafeArea()
            content
        }
    }
}

extension View {
    func rrDebugSafeArea() -> some View {
        modifier(SafeAreaDebugOverlay())
    }
}

