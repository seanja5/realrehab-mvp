//
//  LessonView.swift
//  RealRehabPractice
//
//  Created by Sean Andrews on 10/28/25.
//

import SwiftUI
import Combine

struct LessonView: View {
    @EnvironmentObject var router: Router                     // ← add router for navigation
    @StateObject private var engine = LessonEngine()
    @State private var sim = PracticeSensorSimulator()
    @State private var cancellable: AnyCancellable?
    @State private var running = false
    @State private var flashOpacity: Double = 0.0
    @State private var randomSimulationRunning = false

    var body: some View {
        VStack(spacing: 16) {
            // Simple custom header (kept from your version)
            HStack {
                Image(systemName: "chevron.left")
                Spacer()
                Text("Knee Extension").font(.headline)
                Spacer()
                Spacer().frame(width: 18)
            }
            .padding(.horizontal)

            // Target control
            VStack(alignment: .leading) {
                Text("Target: \(Int(engine.targets.kneeTargetDeg))°")
                    .font(.caption).foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { engine.targets.kneeTargetDeg },
                        set: { engine.targets.kneeTargetDeg = $0 }
                    ),
                    in: 120...175,
                    step: 1
                )
            }
            .padding(.horizontal)

            // Rep counter
            Text("# of Repetitions: \(engine.repCount)/20")
                .font(.subheadline).monospacedDigit()
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            // Feedback card with red/green flash
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(engine.lastEvaluation.isCorrect ? Color.green.opacity(0.35) : Color.red.opacity(0.35))
                    .opacity(flashOpacity)
                    .animation(.easeOut(duration: 0.25), value: flashOpacity)

                VStack(spacing: 12) {
                    Button {
                        running ? stop() : start()
                    } label: {
                        Image(systemName: running ? "stop.fill" : "play.fill")
                            .font(.system(size: 48, weight: .bold))
                    }

                    Text(
                        engine.lastEvaluation.isCorrect
                        ? "Keep it coming!"
                        : (engine.lastEvaluation.reason ?? "Not Quite!")
                    )
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: 360)
            .background(
                LinearGradient(colors: [.clear, .black.opacity(0.08)],
                               startPoint: .top, endPoint: .bottom)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
            )
            .padding(.horizontal)

            Spacer()

            // Controls
            VStack(spacing: 12) {
                Button(randomSimulationRunning ? "Stop Random Test" : "Start Random Test") {
                    if randomSimulationRunning {
                        engine.stopRandomSimulation()
                    } else {
                        engine.startRandomSimulation()
                    }
                    randomSimulationRunning.toggle()
                }
                .buttonStyle(.bordered)
                .tint(randomSimulationRunning ? .red : .blue)

                Button("Complete Session!") {
                    stop()
                    router.go(.completion)                 // ← navigate to completion
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom, 24)
        }
        // Flash effect on correctness change
        .onChange(of: engine.lastEvaluation.isCorrect) { _, _ in
            flashOpacity = 0.75
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { flashOpacity = 0.0 }
        }
        // Auto-advance when reps hit 20
        .onChange(of: engine.repCount) { _, newValue in
            if newValue >= 20 {
                stop()
                router.go(.completion)                     // ← auto-advance
            }
        }
    }

    private func start() {
        engine.reset()
        sim.start()
        cancellable = sim.publisher
            .receive(on: DispatchQueue.main)
            .sink { sample in engine.ingest(sample) }
        running = true
    }

    private func stop() {
        sim.stop()
        cancellable?.cancel(); cancellable = nil
        engine.stopRandomSimulation()
        randomSimulationRunning = false
        running = false
    }
}