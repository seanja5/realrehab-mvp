//
//  LessonEngine.swift
//  RealRehabPractice
//
//  Created by Sean Andrews on 10/28/25.
//
import Foundation
import Combine

struct LessonTargets {
    var kneeTargetDeg: Double = 160      // target to "pass"
    var kneeResetDeg: Double  = 120      // must drop below to re-arm next rep
    var maxHipDriftDeg: Double = 8       // keep hips steady
    var minFlex: Double = 0.55           // min quad activation at peak
}

struct Evaluation {
    let isCorrect: Bool
    let reason: String?
}

final class LessonEngine: ObservableObject {
    @Published private(set) var repCount: Int = 0
    @Published private(set) var lastEvaluation: Evaluation = .init(isCorrect: false, reason: "Waiting…")

    private var inCooldown = false
    private var simulationTimer: Timer?
    var targets = LessonTargets()

    func reset() {
        repCount = 0
        inCooldown = false
        lastEvaluation = .init(isCorrect: false, reason: "Waiting…")
    }
    
    func startRandomSimulation() {
        stopRandomSimulation()
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Randomly decide if this sample should be correct or incorrect
            let isCorrectSample = Bool.random()
            
            let sample: SensorSample
            if isCorrectSample {
                // Generate a correct sample - all criteria pass
                sample = SensorSample(
                    kneeAngleDeg: self.targets.kneeTargetDeg + Double.random(in: 0...10), // Above target
                    hipDriftDeg: Double.random(in: 0..<self.targets.maxHipDriftDeg), // Below max
                    flexActivation: Double.random(in: self.targets.minFlex...1.0) // Above min
                )
            } else {
                // Generate an incorrect sample - one or more criteria fail
                let failureType = Int.random(in: 0..<3)
                switch failureType {
                case 0:
                    // Knee angle too low
                    sample = SensorSample(
                        kneeAngleDeg: Double.random(in: 120..<self.targets.kneeTargetDeg),
                        hipDriftDeg: Double.random(in: 0..<self.targets.maxHipDriftDeg),
                        flexActivation: Double.random(in: self.targets.minFlex...1.0)
                    )
                case 1:
                    // Hip drift too high
                    sample = SensorSample(
                        kneeAngleDeg: self.targets.kneeTargetDeg + Double.random(in: 0...10),
                        hipDriftDeg: self.targets.maxHipDriftDeg + Double.random(in: 1...10),
                        flexActivation: Double.random(in: self.targets.minFlex...1.0)
                    )
                default:
                    // Flex activation too low
                    sample = SensorSample(
                        kneeAngleDeg: self.targets.kneeTargetDeg + Double.random(in: 0...10),
                        hipDriftDeg: Double.random(in: 0..<self.targets.maxHipDriftDeg),
                        flexActivation: Double.random(in: 0.0..<self.targets.minFlex)
                    )
                }
            }
            
            self.ingest(sample)
        }
    }
    
    func stopRandomSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
    }

    func ingest(_ s: SensorSample) {
        var ok = true
        var problems = [String]()

        if s.kneeAngleDeg < targets.kneeTargetDeg {
            ok = false; problems.append("Finish the full extension.")
        }
        if s.hipDriftDeg > targets.maxHipDriftDeg {
            ok = false; problems.append("Keep your hips steady.")
        }
        if s.flexActivation < targets.minFlex {
            ok = false; problems.append("Activate quads a bit more.")
        }

        lastEvaluation = Evaluation(isCorrect: ok, reason: ok ? nil : problems.joined(separator: " "))

        // Count a rep when above target while OK; re-arm once below reset.
        if !inCooldown, s.kneeAngleDeg >= targets.kneeTargetDeg, ok {
            repCount += 1
            inCooldown = true
        } else if inCooldown, s.kneeAngleDeg <= targets.kneeResetDeg {
            inCooldown = false
        }
    }
}
