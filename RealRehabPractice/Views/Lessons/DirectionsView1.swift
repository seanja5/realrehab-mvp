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

    init(reps: Int? = nil, restSec: Int? = nil, lessonId: UUID? = nil, lessonTitle: String? = nil) {
        self.reps = reps
        self.restSec = restSec
        self.lessonId = lessonId
        self.lessonTitle = lessonTitle
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
        // Default: knee extensions
        return "With your brace on, sit comfortably, and place your leg in its resting position."
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
                router.go(.directionsView2(reps: reps, restSec: restSec, lessonId: lessonId, lessonTitle: lessonTitle))
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
