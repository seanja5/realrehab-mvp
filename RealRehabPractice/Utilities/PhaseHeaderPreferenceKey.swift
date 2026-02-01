import SwiftUI

// MARK: - Phase logic: anchor-based (phaseMinY and headerBottomGlobal in .global)
enum JourneyMapPhaseHeader {
    /// Named coordinate space on the ScrollView (optional; phase anchors use .global).
    static let coordinateSpaceName = "journeyScroll"

    /// activePhase = max(phase where phaseMinY <= headerBottomGlobal); fallback 1 if none crossed.
    /// Both thresholdY (header bottom) and phase anchor minY must be in .global.
    static func activePhase(thresholdY: CGFloat, phasePositions: [Int: CGFloat]) -> Int {
        let crossed = phasePositions.filter { $0.value <= thresholdY }
        return crossed.keys.max() ?? 1
    }
}

// MARK: - Scroll content top reports its minY in journeyScroll (scroll offset)
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Sticky header reports its bottom edge (maxY) in global coordinates
struct StickyHeaderBottomPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat { 0 }
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Phase dividers report their minY in global (merge by phase index)
struct PhaseHeaderPreferenceKey: PreferenceKey {
    static var defaultValue: [Int: CGFloat] { [:] }
    static func reduce(value: inout [Int: CGFloat], nextValue: () -> [Int: CGFloat]) {
        for (k, v) in nextValue() {
            value[k] = v
        }
    }
}

// MARK: - Modifier: report this view's bottom edge (maxY) in global — attach to sticky header card
struct ReportHeaderBottomModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: StickyHeaderBottomPreferenceKey.self,
                            value: geometry.frame(in: .global).maxY
                        )
                }
            )
    }
}

// MARK: - Modifier: report this view's minY in global for the given phase — attach to each phase divider
struct PhaseHeaderPositionModifier: ViewModifier {
    let phase: Int
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: PhaseHeaderPreferenceKey.self,
                            value: [phase: geometry.frame(in: .global).minY]
                        )
                }
            )
    }
}

extension View {
    /// Reports this view's bottom edge (maxY) in global. Attach to the sticky header card.
    func reportHeaderBottom() -> some View {
        modifier(ReportHeaderBottomModifier())
    }

    /// Reports this view's minY in journeyScroll for the given phase. Attach to phase 1 anchor and dividers 2, 3, 4.
    func phaseHeaderPosition(phase: Int) -> some View {
        modifier(PhaseHeaderPositionModifier(phase: phase))
    }
}
