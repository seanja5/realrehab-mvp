//
//  DirectionsView1.swift
//  RealRehabPractice
//

import SwiftUI

struct DirectionsView1: View {
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
            return "Sit comfortably with your brace on and your leg straight out in front of you, resting on a flat surface."
        }
        if t.contains("short arc") {
            return "Sit or lie with your brace on, with your knee bent at about 45°. Place a rolled towel or bolster under your knee to support it."
        }
        if t.contains("heel slide") {
            return "Lie flat on your back with your brace on and both legs extended. Keep your heel on the surface throughout the exercise."
        }
        if t.contains("straight leg raise") {
            return "Lie flat on your back with your brace on. Keep your surgical leg completely straight and let your foot relax naturally."
        }
        if t.contains("ankle pump") {
            return "Sit or lie comfortably with your brace on. Your foot should be free to move up and down without restriction."
        }
        // Default: knee extensions
        return "With your brace on, sit comfortably, and place your leg in its resting position."
    }

    /// Returns the bundled mp4 filename (without extension) for this lesson, or nil if none.
    private var videoName: String? {
        let t = lessonTitle?.lowercased() ?? ""
        if t.contains("quad set") { return "BraceOn" }
        if t.contains("knee extension") { return "BraceOn" }
        if t.contains("short arc") { return "LieDown" }
        if t.contains("heel slide") { return "LieDown" }
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
                router.go(.directionsView2(reps: reps, restSec: restSec, lessonId: lessonId, lessonTitle: lessonTitle, sets: sets, setRestSec: setRestSec, holdDurationSec: holdDurationSec))
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
