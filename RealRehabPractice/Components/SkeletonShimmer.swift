//
//  SkeletonShimmer.swift
//  RealRehabPractice
//
//  Skeleton loading placeholders with shimmer animation.
//

import SwiftUI

// MARK: - Shimmer modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shimmerOpacity: Double = colorScheme == .dark ? 0.10 : 0.50
        return content
            .overlay(
                GeometryReader { g in
                    LinearGradient(
                        colors: [.clear, .white.opacity(shimmerOpacity), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: g.size.width * 2)
                    .offset(x: -g.size.width + phase * g.size.width * 2)
                }
                .clipped()
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton block

struct SkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.rrSkeleton)
            .frame(width: width, height: height)
            .shimmer()
    }
}
