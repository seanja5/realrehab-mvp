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

// MARK: - Brand Background helper
extension View {
    func rrPageBackground() -> some View {
        self
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(red: 0.95, green: 0.95, blue: 0.95).ignoresSafeArea())
    }
}

