//
//  DirectionsView2.swift
//  RealRehabPractice
//

import SwiftUI

struct DirectionsView2: View {
    @EnvironmentObject var router: Router
    let reps: Int?
    let restSec: Int?
    let lessonId: UUID?
    let lessonTitle: String?

    init(reps: Int? = nil, restSec: Int? = nil, lessonId: UUID? = nil, lessonTitle: String? = nil) {
        self.reps = reps
        self.restSec = restSec
        self.lessonId = lessonId
        self.lessonTitle = lessonTitle
    }

    private var instructionText: String {
        let t = lessonTitle?.lowercased() ?? ""
        if t.contains("quad set") {
            return "When the bar fills, tighten your thigh muscle and hold your leg still for the duration shown.\n\nKeep your leg flat and avoid any lifting — the goal is muscle contraction, not movement."
        }
        if t.contains("short arc") {
            return "Match the animation: extend your leg to straight as the bar fills, then lower it slowly as it empties.\n\nStart from the 45° position and focus on controlled extension through the final range."
        }
        if t.contains("heel slide") {
            return "Match the animation: slide your heel toward your body as the bar fills, then slowly straighten back out as it empties.\n\nKeep your heel on the surface and move at a steady, controlled pace."
        }
        // Default: knee extensions
        return "Match the animation: extend your leg as the box fills, and rest as it empties.\n\nKeep your thigh centered, avoid hip rotation, and keep your foot off the ground for the entire lesson."
    }

    private var navTitle: String {
        lessonTitle ?? "Lesson"
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(instructionText)
                .font(.rrHeadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .padding(.horizontal, 24)

            Spacer()

            PrimaryButton(
                title: "Next",
                useLargeFont: true
            ) {
                router.go(.lesson(reps: reps, restSec: restSec, lessonId: lessonId, lessonTitle: lessonTitle))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .safeAreaPadding(.bottom)
        }
        .rrPageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .swipeToGoBack()
        .navigationTitle(navTitle)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                BluetoothStatusIndicator()
            }
        }
    }
}
