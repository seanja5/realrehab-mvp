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
            ZStack {
                // Base rounded panel
                RoundedRectangle(cornerRadius: 16)
                    .fill(engine.phase == .incorrectHold
                          ? Color.red
                          : (engine.phase == .idle ? Color.gray.opacity(0.3) : Color.green.opacity(0.25)))
                
                // Green fill overlay only during strokes
                if engine.phase == .upstroke || engine.phase == .downstroke {
                    GeometryReader { geo in
                        let h = geo.size.height
                        // Bottom-anchored fill whose height animates with engine.fill
                        VStack {
                            Spacer()
                            LinearGradient(
                                colors: [Color.green.opacity(0.25), Color.green],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                            .frame(height: max(0, h * max(0.1, engine.fill))) // start at ~10%
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .allowsHitTesting(false)
                }
                
                // Center text
                Text(
                    engine.phase == .idle ? "Waiting…" :
                    (engine.phase == .incorrectHold ? "Not Quite!" :
                     (engine.phase == .upstroke || engine.phase == .downstroke ? "You've Got It!" : "Keep it Coming!"))
                )
                .font(.rrTitle)
                .foregroundStyle(engine.phase == .incorrectHold ? .white : .primary)
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
                    engine.startGuidedSimulation()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            
            // Bottom primary action
            PrimaryButton(
                title: "Complete Session!",
                isDisabled: engine.repCount < 20,
                useLargeFont: true
            ) {
                engine.stopGuidedSimulation()
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
                        engine.stopGuidedSimulation()
                    }
                }
            }
        }
        .onDisappear {
            engine.stopGuidedSimulation()
        }
    }
}
