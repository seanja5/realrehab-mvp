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
    let sets: Int?
    let setRestSec: Int?
    let holdDurationSec: Int?

    init(reps: Int? = nil, restSec: Int? = nil, lessonId: UUID? = nil, lessonTitle: String? = nil, sets: Int? = nil, setRestSec: Int? = nil, holdDurationSec: Int? = nil) {
        self.reps = reps
        self.restSec = restSec
        self.lessonId = lessonId
        self.lessonTitle = lessonTitle
        self.sets = sets
        self.setRestSec = setRestSec
        self.holdDurationSec = holdDurationSec
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
        if t.contains("straight leg raise") {
            return "As the bar fills, slowly lift your straight leg about 12–18 inches off the ground. Lower it with control as the bar empties.\n\nKeep your knee completely straight the entire time — do not let it bend at any point."
        }
        if t.contains("ankle pump") {
            return "Pump your foot upward toward your shin, then back down in a steady rhythm — one pump per cycle of the bar.\n\nMake each movement full and deliberate. These pumps promote circulation and help reduce swelling in your knee."
        }
        if t.contains("extension control") {
            return "When prompted, slowly straighten your knee as far as it will go and hold the position.\n\nFocus on fully locking out the joint. Keep your thigh relaxed — the contraction should come from pressing the back of your knee toward the surface."
        }
        // Default: knee extensions
        return "Match the animation: extend your leg as the box fills, and rest as it empties.\n\nKeep your thigh centered, avoid hip rotation, and keep your foot off the ground for the entire lesson."
    }

    /// Returns the bundled mp4 filename (without extension) for this lesson, or nil if none.
    private var videoName: String? {
        let t = lessonTitle?.lowercased() ?? ""
        if t.contains("quad set") { return "QuadSet" }
        if t.contains("short arc") { return "ShortArcQuad" }
        if t.contains("heel slide") { return "HeelSlides" }
        if t.contains("knee extension") { return "Knee Extension" }
        if t.contains("extension control") { return "ExtensionControl" }
        if t.contains("straight leg raise") { return "StraightLegRaise" }
        return nil
    }

    private var navTitle: String {
        lessonTitle ?? "Lesson"
    }

    var body: some View {
        VStack(spacing: 0) {
            if let name = videoName {
                LoopingVideoView(videoName: name)
                    .frame(maxWidth: .infinity)
                    .frame(height: 260)
                    .clipped()
            }

            Spacer()

            Text(instructionText)
                .font(.rrHeadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .padding(.horizontal, 24)
                .padding(.top, videoName != nil ? 24 : 0)

            Spacer()

            PrimaryButton(
                title: "Next",
                useLargeFont: true
            ) {
                router.go(.lesson(reps: reps, restSec: restSec, lessonId: lessonId, lessonTitle: lessonTitle, sets: sets, setRestSec: setRestSec, holdDurationSec: holdDurationSec))
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
