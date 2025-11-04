//
//  LessonView.swift
//  RealRehabPractice
//
//  Created by Sean Andrews on 10/28/25.
//

import SwiftUI
import Combine

struct LessonView: View {
    @EnvironmentObject var router: Router
    @StateObject private var engine = LessonEngine()
    @State private var hasStarted = false

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // Title
            Text("Knee Extension")
                .font(.rrHeadline)
                .padding(.top, 8)
            
            // Progress (non-interactive)
            VStack(spacing: 8) {
                ProgressView(value: min(Double(engine.repCount) / 20.0, 1.0))
                    .progressViewStyle(.linear)
                    .tint(Color.brandDarkBlue)
                    .padding(.horizontal, 16)
                
                Text("Repetitions: \(engine.repCount)/20")
                    .font(.rrCallout)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.top, 8)
            
            // Feedback card (no play icon)
            Group {
                if engine.lastEvaluation.isCorrect {
                    // green card
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(
                            colors: [Color.green.opacity(0.25), Color.green],
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                        .overlay(
                            Text("Keep it coming!")
                                .font(.rrTitle)
                                .foregroundStyle(.primary)
                        )
                } else {
                    // red card with message
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.red)
                        .overlay(
                            VStack(spacing: 8) {
                                Text("Not Quite!")
                                    .font(.rrTitle)
                                
                                if let reason = engine.lastEvaluation.reason, !reason.isEmpty {
                                    Text(reason)
                                        .font(.rrBody)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 12)
                                }
                            }
                            .foregroundStyle(.white)
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Spacer(minLength: 16)
            
            // Controls row (secondary begin button)
            HStack {
                SecondaryButton(
                    title: hasStarted ? "Lesson Running…" : "Begin Lesson",
                    isDisabled: hasStarted
                ) {
                    guard !hasStarted else { return }
                    hasStarted = true
                    engine.reset()
                    engine.startRandomSimulation()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            
            // Bottom primary action
            PrimaryButton(title: "Complete Session!", useLargeFont: true) {
                engine.stopRandomSimulation()
                router.go(.completion)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .safeAreaPadding(.bottom)
        }
        .rrPageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton {
                    // Clean up running session before going back
                    if hasStarted {
                        engine.stopRandomSimulation()
                    }
                }
            }
        }
        .onDisappear {
            engine.stopRandomSimulation()
        }
        // Auto-advance when reps hit 20
        .onChange(of: engine.repCount) { _, newValue in
            if newValue >= 20 {
                engine.stopRandomSimulation()
                router.go(.completion)
            }
        }
    }
}
