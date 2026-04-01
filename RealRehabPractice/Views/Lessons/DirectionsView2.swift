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

    private var t: String { lessonTitle?.lowercased() ?? "" }

    private var instructionText: String {
        if t.contains("quad set") {
            return "Follow the animation on screen. Extend your leg as the bar fills and rest it as it empties. When the bar reaches the top, hold your leg in the extended position for the duration shown."
        }
        if t.contains("short arc") {
            return "Match the animation: extend your leg to straight as the bar fills, then lower it back to rest as it empties. Keep your knee rested on the roller the entire time."
        }
        if t.contains("heel slide") {
            return "Start with your knee bent and match the animation: straighten your leg out as the bar fills, then slowly slide your heel back toward your body as it empties. Keep your heel on the surface the whole time."
        }
        if t.contains("straight leg raise") {
            return "As the bar fills, slowly lift your straight leg about 12–18 inches off the ground. Lower it with control as the bar empties.\n\nKeep your knee completely straight the entire time — do not let it bend at any point."
        }
        if t.contains("ankle pump") {
            return "Pump your foot upward toward your shin, then back down in a steady rhythm — one pump per cycle of the bar.\n\nMake each movement full and deliberate. These pumps promote circulation and help reduce swelling in your knee."
        }
        // Default: knee extensions
        return "Match the animation: extend your leg as the bar fills, and rest as it empties.\n\nKeep your thigh centered, avoid hip rotation, and keep your foot off the ground for the entire lesson."
    }

    /// Returns the bundled mp4 filename (without extension) for this lesson, or nil if none.
    private var videoName: String? {
        if t.contains("quad set") { return "QuadSet" }
        if t.contains("short arc") { return "ShortArcQuad" }
        if t.contains("heel slide") { return "HeelSlides" }
        if t.contains("knee extension") { return "Knee Extension" }
        return nil
    }

    private var navTitle: String { lessonTitle ?? "Lesson" }

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

            PrimaryButton(title: "Next", useLargeFont: true) {
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
