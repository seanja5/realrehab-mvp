//
//  DirectionsView1.swift
//  RealRehabPractice
//
//  Created by Sean Andrews on 12/7/25.
//

import SwiftUI

struct DirectionsView1: View {
    @EnvironmentObject var router: Router
    let reps: Int?
    let restSec: Int?
    let lessonId: UUID?
    
    init(reps: Int? = nil, restSec: Int? = nil, lessonId: UUID? = nil) {
        self.reps = reps
        self.restSec = restSec
        self.lessonId = lessonId
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Main instruction text
            Text("With your brace on, sit comfortably, and place your leg in its resting position.")
                .font(.rrHeadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
                .padding(.horizontal, 24)
            
            Spacer()
            
            // Next button
            PrimaryButton(
                title: "Next",
                useLargeFont: true
            ) {
                router.go(.directionsView2(reps: reps, restSec: restSec, lessonId: lessonId))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .safeAreaPadding(.bottom)
        }
        .rrPageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationTitle("Knee Extensions")
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

