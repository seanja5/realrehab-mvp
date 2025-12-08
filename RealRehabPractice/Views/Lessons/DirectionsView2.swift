//
//  DirectionsView2.swift
//  RealRehabPractice
//
//  Created by Sean Andrews on 12/7/25.
//

import SwiftUI

struct DirectionsView2: View {
    @EnvironmentObject var router: Router
    let reps: Int?
    let restSec: Int?
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Main instruction text
            Text("Match the animation: extend your leg as the box fills, and rest as it empties.\n\nKeep your thigh centered, avoid hip rotation, and keep your foot off the ground for the entire lesson.")
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
                router.go(.lesson(reps: reps, restSec: restSec))
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

