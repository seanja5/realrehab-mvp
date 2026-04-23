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

    private var t: String { lessonTitle?.lowercased() ?? "" }

    private var isBenchmark: Bool {
        t.contains("extension control") || t.contains("straight leg raise control")
    }

    private var instructionText: String {
        if t.contains("quad set") {
            return "Put your brace on as shown in the video above, ensuring the hole of the brace is centered over your kneecap. Then sit comfortably with your leg in its natural resting position to prepare for calibration."
        }
        if t.contains("short arc") {
            return "Put your brace on as shown in the video above, ensuring the hole of the brace is centered over your kneecap. Then lie down on a comfortable surface. You will also need a foam roller for this exercise."
        }
        if t.contains("heel slide") {
            return "Put your brace on as shown in the video above, ensuring the hole of the brace is centered over your kneecap. Then lie down on a comfortable surface to prepare for calibration."
        }
        if t.contains("extension control") {
            return "Put your brace on as shown in the video above, ensuring the hole of the brace is centered over your kneecap. Then sit down comfortably to prepare for calibration."
        }
        if t.contains("straight leg raise control") {
            return "Put your brace on as shown in the video above, ensuring the hole of the brace is centered over your kneecap. Then lie down on a comfortable surface to prepare for calibration."
        }
        if t.contains("straight leg raise") {
            return "Put your brace on as shown in the video above, ensuring the hole of the brace is centered over your kneecap. Then lie flat on your back, keep your surgical leg completely straight, and let your foot relax naturally."
        }
        if t.contains("ankle pump") {
            return "Put your brace on as shown in the video above, ensuring the hole of the brace is centered over your kneecap. Then sit or lie comfortably with your foot free to move up and down without restriction."
        }
        // Default: knee extensions
        return "Put your brace on as shown in the video above, ensuring the hole of the brace is centered over your kneecap. Then sit comfortably with your leg in its natural resting position to prepare for calibration."
    }

    /// Returns the bundled mp4 filename (without extension) for this lesson, or nil if none.
    private var videoName: String? {
        if t.contains("quad set") { return "BraceOn" }
        if t.contains("knee extension") { return "BraceOn" }
        if t.contains("extension control") { return "BraceOn" }
        if t.contains("straight leg raise control") { return "LieDown" }
        if t.contains("short arc") { return "LieDown" }
        if t.contains("heel slide") { return "LieDown" }
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

            VStack(spacing: 16) {
                // Required Equipment pill — shown only for Short Arc Quad
                if t.contains("short arc") {
                    HStack(spacing: 8) {
                        Image(systemName: "cylinder.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.brandDarkBlue)
                        Text("Required Equipment: Foam Roller")
                            .font(.rrCaption.bold())
                            .foregroundStyle(Color.brandDarkBlue)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Color.brandDarkBlue.opacity(0.09))
                    .clipShape(Capsule())
                }

                Text(instructionText)
                    .font(.rrHeadline)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 24)
            }

            Spacer()

            PrimaryButton(title: "Next", useLargeFont: true) {
                if isBenchmark, let lid = lessonId, let lt = lessonTitle {
                    router.go(.benchmarkCalibrateDevice(
                        holdDuration: holdDurationSec ?? 8,
                        reps: reps ?? 0,
                        restSec: restSec ?? 0,
                        lessonId: lid,
                        lessonTitle: lt
                    ))
                } else {
                    router.go(.calibrateDevice(
                        reps: reps,
                        restSec: restSec,
                        lessonId: lessonId,
                        lessonTitle: lessonTitle,
                        sets: sets,
                        setRestSec: setRestSec,
                        holdDurationSec: holdDurationSec
                    ))
                }
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
