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

enum Phase {
    case idle
    case incorrectHold
    case upstroke
    case downstroke
}

final class LessonEngine: ObservableObject {
    @Published private(set) var repCount: Int = 0
    @Published private(set) var lastEvaluation: Evaluation = .init(isCorrect: false, reason: "Waiting…")
    @Published var phase: Phase = .idle
    @Published var fill: Double = 0.0  // 0.0...1.0 for the green overlay fill
    @Published var statusText: String = "Waiting…"
    
    let repTarget = 20

    private var inCooldown = false
    private var simulationTimer: Timer?
    private var guidedRunToken: UUID?
    private var animationTimer: Timer?
    var targets = LessonTargets()

    func reset() {
        repCount = 0
        inCooldown = false
        lastEvaluation = .init(isCorrect: false, reason: "Waiting…")
        phase = .idle
        fill = 0.0
        statusText = "Waiting…"
        stopGuidedSimulation()
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
    
    func startGuidedSimulation() {
        stopGuidedSimulation()
        let token = UUID()
        guidedRunToken = token
        
        // Start with incorrectHold for 3 seconds
        runIncorrectHold(duration: 3.0, token: token)
    }
    
    func stopGuidedSimulation() {
        guidedRunToken = nil
        animationTimer?.invalidate()
        animationTimer = nil
        phase = .idle
        fill = 0.0
        statusText = "Waiting…"
        lastEvaluation = .init(isCorrect: false, reason: "Waiting…")
    }
    
    private func runIncorrectHold(duration: TimeInterval, token: UUID) {
        guard guidedRunToken == token else { return }
        
        phase = .incorrectHold
        fill = 0.0
        statusText = "Not Quite!"
        lastEvaluation = .init(isCorrect: false, reason: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self = self, self.guidedRunToken == token else { return }
            
            // Check if we've reached target
            if self.repCount >= self.repTarget {
                self.phase = .idle
                self.statusText = "Great work!"
                self.fill = 1.0
                self.lastEvaluation = .init(isCorrect: true, reason: nil)
                return
            }
            
            self.runUpstroke(token: token)
        }
    }
    
    private func runUpstroke(token: UUID) {
        guard guidedRunToken == token else { return }
        
        phase = .upstroke
        statusText = "Keep it Coming!"
        lastEvaluation = .init(isCorrect: true, reason: nil)
        
        // Start fill at 0.1 (10%)
        fill = 0.1
        
        // Animate fill to 1.0 over 3 seconds using linear interpolation
        let startTime = Date()
        let duration: TimeInterval = 3.0
        let startFill: Double = 0.1
        let endFill: Double = 1.0
        
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] timer in
            guard let self = self, self.guidedRunToken == token else {
                timer.invalidate()
                return
            }
            
            DispatchQueue.main.async {
                let elapsed = Date().timeIntervalSince(startTime)
                let progress = min(elapsed / duration, 1.0)
                self.fill = startFill + (endFill - startFill) * progress
                
                if progress >= 1.0 {
                    timer.invalidate()
                    self.animationTimer = nil
                    
                    // Increment rep count when fill reaches top
                    self.repCount += 1
                    
                    // Check if we've reached target
                    if self.repCount >= self.repTarget {
                        self.phase = .idle
                        self.statusText = "Great work!"
                        self.fill = 1.0
                        self.lastEvaluation = .init(isCorrect: true, reason: nil)
                        return
                    }
                    
                    // Check if we need a 4-rep pause
                    if self.repCount % 4 == 0 {
                        self.runIncorrectHold(duration: 2.0, token: token)
                    } else {
                        self.runDownstroke(token: token)
                    }
                }
            }
        }
        RunLoop.main.add(animationTimer!, forMode: .common)
    }
    
    private func runDownstroke(token: UUID) {
        guard guidedRunToken == token else { return }
        
        phase = .downstroke
        statusText = "Keep it Coming!"
        lastEvaluation = .init(isCorrect: true, reason: nil)
        
        // Animate fill from 1.0 to 0.0 over 3 seconds using linear interpolation
        let startTime = Date()
        let duration: TimeInterval = 3.0
        let startFill: Double = 1.0
        let endFill: Double = 0.0
        
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] timer in
            guard let self = self, self.guidedRunToken == token else {
                timer.invalidate()
                return
            }
            
            DispatchQueue.main.async {
                let elapsed = Date().timeIntervalSince(startTime)
                let progress = min(elapsed / duration, 1.0)
                self.fill = startFill + (endFill - startFill) * progress
                
                if progress >= 1.0 {
                    timer.invalidate()
                    self.animationTimer = nil
                    
                    // Check if we've reached target
                    if self.repCount >= self.repTarget {
                        self.phase = .idle
                        self.statusText = "Great work!"
                        self.fill = 1.0
                        self.lastEvaluation = .init(isCorrect: true, reason: nil)
                        return
                    }
                    
                    // Continue cycling
                    self.runUpstroke(token: token)
                }
            }
        }
        RunLoop.main.add(animationTimer!, forMode: .common)
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
