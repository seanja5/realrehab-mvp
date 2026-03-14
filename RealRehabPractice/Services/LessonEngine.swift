//
//  LessonEngine.swift
//  RealRehabPractice
//
import Foundation
import Combine

// MARK: - Exercise type (determines state-machine behaviour)

enum ExerciseType {
    /// Knee extension / Short Arc Quad: fill rises = more extension, rep counted at peak. Default.
    case kneeExtension
    /// Quad Sets: upstroke brings leg near extension, then hold for `holdDuration` seconds.
    /// Rep counted only if angle stays above `holdThresholdDeg` for the full hold.
    case isometricHold(holdThresholdDeg: Double, holdDuration: TimeInterval)
    /// Heel Slides: fill rises = more flexion (engine fills normally; view inverts display).
    /// Rep counted when fill reaches peak (flexion target validated externally in LessonView).
    case kneeFlex
}

/// Derive ExerciseType from a lesson title string.
extension ExerciseType {
    static func from(lessonTitle: String?) -> ExerciseType {
        let t = lessonTitle?.lowercased() ?? ""
        if t.contains("quad set") {
            // Default hold threshold 155°; hold duration 5s unless overridden by restSec
            return .isometricHold(holdThresholdDeg: 155, holdDuration: 5)
        }
        if t.contains("heel slide") {
            return .kneeFlex
        }
        // Short Arc Quad, Seated Knee Extensions, and any unknown → extension engine
        return .kneeExtension
    }
}

// MARK: - Sensor targets

struct LessonTargets {
    var kneeTargetDeg: Double = 160      // extension target to "pass"
    var kneeResetDeg: Double  = 120      // must drop below to re-arm next rep
    var maxHipDriftDeg: Double = 8       // keep hips steady
    var minFlex: Double = 0.55           // (simulation only)
    // Flexion targets (Heel Slides)
    var flexionTargetDeg: Double = 130   // must bend to at least this
    var flexionResetDeg: Double  = 155   // must straighten above this to re-arm
}

/// Per-exercise default targets.
extension LessonTargets {
    static func defaults(for type: ExerciseType, lessonTitle: String?) -> LessonTargets {
        let t = lessonTitle?.lowercased() ?? ""
        switch type {
        case .kneeExtension:
            var targets = LessonTargets()
            if t.contains("short arc") {
                targets.kneeTargetDeg = 155
                targets.kneeResetDeg  = 110
                targets.maxHipDriftDeg = t.contains("control") ? 6 : 8
            } else if t.contains("strength") {
                targets.kneeTargetDeg = 160
                targets.kneeResetDeg  = 120
                targets.maxHipDriftDeg = 6
            } else {
                // standard knee extension
                targets.kneeTargetDeg = 160
                targets.kneeResetDeg  = 120
                targets.maxHipDriftDeg = 8
            }
            return targets
        case .isometricHold:
            var targets = LessonTargets()
            targets.kneeTargetDeg = 155
            targets.kneeResetDeg  = 130
            targets.maxHipDriftDeg = 6
            return targets
        case .kneeFlex:
            var targets = LessonTargets()
            targets.flexionTargetDeg = 130
            targets.flexionResetDeg  = 155
            targets.maxHipDriftDeg   = 8
            return targets
        }
    }
}

// MARK: - Evaluation

struct Evaluation {
    let isCorrect: Bool
    let reason: String?
}

// MARK: - Phase

enum Phase {
    case idle
    case incorrectHold
    case upstroke
    case holding      // isometric hold at peak (isometricHold type only)
    case downstroke
}

// MARK: - LessonEngine

final class LessonEngine: ObservableObject {
    @Published private(set) var repCount: Int = 0
    @Published private(set) var lastEvaluation: Evaluation = .init(isCorrect: false, reason: "Waiting…")
    @Published var phase: Phase = .idle
    @Published var fill: Double = 0.0  // 0.0...1.0 for the green overlay fill
    @Published var statusText: String = "Waiting…"
    @Published var isPaused: Bool = false
    /// Remaining hold seconds shown in UI during isometric hold phase.
    @Published private(set) var holdSecondsRemaining: Int = 0

    let repTarget: Int
    let restDuration: TimeInterval  // total cycle time (extension); hold duration (isometric)
    let exerciseType: ExerciseType

    private var inCooldown = false
    private var simulationTimer: Timer?
    private var guidedRunToken: UUID?
    private var animationTimer: Timer?
    private var holdTimer: Timer?
    private var pausedFill: Double = 0.0
    var targets = LessonTargets()

    // Callback: returns true if rep should be counted (LessonView validates sensors)
    var shouldCountRepCallback: (() -> Bool)? = nil

    // MARK: Init

    init(repTarget: Int = 20, restDuration: TimeInterval = 6.0, exerciseType: ExerciseType = .kneeExtension) {
        self.repTarget = repTarget
        self.restDuration = restDuration
        self.exerciseType = exerciseType
    }

    // MARK: Reset / Restore

    func reset() {
        repCount = 0
        inCooldown = false
        lastEvaluation = .init(isCorrect: false, reason: "Waiting…")
        phase = .idle
        fill = 0.0
        statusText = "Waiting…"
        isPaused = false
        pausedFill = 0.0
        holdSecondsRemaining = 0
        stopGuidedSimulation()
    }

    func restoreSession(repCount: Int) {
        self.repCount = min(repCount, repTarget)
    }

    // MARK: Pause / Resume

    func pauseAnimation() {
        guard !isPaused else { return }
        isPaused = true
        pausedFill = fill
        animationTimer?.invalidate()
        animationTimer = nil
        holdTimer?.invalidate()
        holdTimer = nil
    }

    func resumeAnimation() {
        guard isPaused, let token = guidedRunToken else { return }
        isPaused = false

        switch phase {
        case .upstroke:
            let totalDuration = upstrokeDuration
            let elapsedFill = pausedFill - 0.1
            let elapsedTime = (elapsedFill / 0.9) * totalDuration
            let remainingTime = totalDuration - elapsedTime
            continueUpstroke(fromFill: pausedFill, remainingTime: remainingTime, token: token)
        case .holding:
            // Resume hold from remaining seconds
            resumeHold(remainingSeconds: holdSecondsRemaining, token: token)
        case .downstroke:
            let totalDuration = downstrokeDuration
            let elapsedFill = 1.0 - pausedFill
            let elapsedTime = elapsedFill * totalDuration
            let remainingTime = totalDuration - elapsedTime
            continueDownstroke(fromFill: pausedFill, remainingTime: remainingTime, token: token)
        default:
            break
        }
    }

    // MARK: Timing helpers

    /// Duration of the upstroke animation.
    private var upstrokeDuration: TimeInterval {
        switch exerciseType {
        case .isometricHold: return 1.5
        case .kneeExtension, .kneeFlex: return restDuration / 2.0
        }
    }

    /// Duration of the downstroke animation.
    private var downstrokeDuration: TimeInterval {
        switch exerciseType {
        case .isometricHold: return 2.0
        case .kneeExtension, .kneeFlex: return restDuration / 2.0
        }
    }

    /// Hold duration for isometricHold type. Uses `restDuration` (set from PT's restSec param).
    private var holdDuration: TimeInterval {
        switch exerciseType {
        case .isometricHold: return restDuration  // PT's restSec = hold seconds
        default: return 0
        }
    }

    // MARK: Start/Stop guided simulation

    func startGuidedSimulation(skipInitialWait: Bool = false) {
        stopGuidedSimulation()
        let token = UUID()
        guidedRunToken = token

        if skipInitialWait {
            runUpstroke(token: token)
        } else {
            runIncorrectHold(duration: 3.0, token: token)
        }
    }

    func stopGuidedSimulation() {
        guidedRunToken = nil
        animationTimer?.invalidate()
        animationTimer = nil
        holdTimer?.invalidate()
        holdTimer = nil
        phase = .idle
        fill = 0.0
        statusText = "Waiting…"
        lastEvaluation = .init(isCorrect: false, reason: "Waiting…")
        isPaused = false
        holdSecondsRemaining = 0
    }

    func restartFromBottom() {
        guard let token = guidedRunToken else { return }
        animationTimer?.invalidate()
        animationTimer = nil
        holdTimer?.invalidate()
        holdTimer = nil
        isPaused = false
        fill = 0.1
        runUpstroke(token: token)
    }

    func startOrRestartFromBottom() {
        if guidedRunToken != nil {
            restartFromBottom()
        } else {
            startGuidedSimulation(skipInitialWait: true)
        }
    }

    // MARK: - Private state machine

    private func runIncorrectHold(duration: TimeInterval, token: UUID) {
        guard guidedRunToken == token else { return }
        phase = .incorrectHold
        fill = 0.0
        statusText = "Not Quite!"
        lastEvaluation = .init(isCorrect: false, reason: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self = self, self.guidedRunToken == token else { return }
            if self.repCount >= self.repTarget {
                self.finishLesson()
                return
            }
            self.runUpstroke(token: token)
        }
    }

    private func runUpstroke(token: UUID) {
        guard guidedRunToken == token else { return }
        phase = .upstroke
        statusText = upstrokeStatusText
        lastEvaluation = .init(isCorrect: true, reason: nil)
        fill = 0.1

        let startTime = Date()
        let duration = upstrokeDuration
        let startFill: Double = 0.1
        let endFill: Double = 1.0

        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] timer in
            guard let self = self, self.guidedRunToken == token, !self.isPaused else {
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
                    self.onUpstrokeComplete(token: token)
                }
            }
        }
        RunLoop.main.add(animationTimer!, forMode: .common)
    }

    private func onUpstrokeComplete(token: UUID) {
        switch exerciseType {
        case .isometricHold:
            // Transition to hold phase; rep counted after hold
            runHold(token: token)
        case .kneeExtension, .kneeFlex:
            // Count rep immediately (callback validates sensor)
            let shouldCount = shouldCountRepCallback?() ?? true
            if shouldCount { repCount += 1 }
            if repCount >= repTarget { finishLesson(); return }
            runDownstroke(token: token)
        }
    }

    // MARK: Isometric hold phase

    private func runHold(token: UUID) {
        guard guidedRunToken == token else { return }
        phase = .holding
        statusText = "Hold It!"
        fill = 1.0
        let seconds = Int(holdDuration.rounded())
        holdSecondsRemaining = seconds

        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self, self.guidedRunToken == token, !self.isPaused else {
                timer.invalidate()
                return
            }
            DispatchQueue.main.async {
                self.holdSecondsRemaining = max(0, self.holdSecondsRemaining - 1)
                if self.holdSecondsRemaining <= 0 {
                    timer.invalidate()
                    self.holdTimer = nil
                    self.onHoldComplete(token: token)
                }
            }
        }
        RunLoop.main.add(holdTimer!, forMode: .common)
    }

    private func resumeHold(remainingSeconds: Int, token: UUID) {
        guard guidedRunToken == token else { return }
        phase = .holding
        statusText = "Hold It!"
        fill = 1.0
        holdSecondsRemaining = remainingSeconds

        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self, self.guidedRunToken == token, !self.isPaused else {
                timer.invalidate()
                return
            }
            DispatchQueue.main.async {
                self.holdSecondsRemaining = max(0, self.holdSecondsRemaining - 1)
                if self.holdSecondsRemaining <= 0 {
                    timer.invalidate()
                    self.holdTimer = nil
                    self.onHoldComplete(token: token)
                }
            }
        }
        RunLoop.main.add(holdTimer!, forMode: .common)
    }

    private func onHoldComplete(token: UUID) {
        // Rep counts only if callback confirms hold was maintained
        let shouldCount = shouldCountRepCallback?() ?? true
        if shouldCount { repCount += 1 }
        if repCount >= repTarget { finishLesson(); return }
        runDownstroke(token: token)
    }

    // MARK: Downstroke

    private func runDownstroke(token: UUID) {
        guard guidedRunToken == token else { return }
        phase = .downstroke
        statusText = downstrokeStatusText
        lastEvaluation = .init(isCorrect: true, reason: nil)

        let startTime = Date()
        let duration = downstrokeDuration
        let startFill: Double = 1.0
        let endFill: Double = 0.0

        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] timer in
            guard let self = self, self.guidedRunToken == token else {
                timer.invalidate()
                return
            }
            DispatchQueue.main.async {
                guard !self.isPaused else { return }
                let elapsed = Date().timeIntervalSince(startTime)
                let progress = min(elapsed / duration, 1.0)
                self.fill = startFill + (endFill - startFill) * progress
                if progress >= 1.0 {
                    timer.invalidate()
                    self.animationTimer = nil
                    if self.repCount >= self.repTarget { self.finishLesson(); return }
                    self.runUpstroke(token: token)
                }
            }
        }
        RunLoop.main.add(animationTimer!, forMode: .common)
    }

    // MARK: Finish

    private func finishLesson() {
        phase = .idle
        statusText = "Great work!"
        fill = 1.0
        lastEvaluation = .init(isCorrect: true, reason: nil)
    }

    // MARK: Resume helpers (continue mid-animation after unpause)

    private func continueUpstroke(fromFill: Double, remainingTime: TimeInterval, token: UUID) {
        guard guidedRunToken == token else { return }
        let startTime = Date()
        let startFill = fromFill
        let endFill = 1.0

        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] timer in
            guard let self = self, self.guidedRunToken == token, !self.isPaused else {
                timer.invalidate()
                return
            }
            DispatchQueue.main.async {
                let elapsed = Date().timeIntervalSince(startTime)
                let progress = min(elapsed / remainingTime, 1.0)
                self.fill = startFill + (endFill - startFill) * progress
                if progress >= 1.0 {
                    timer.invalidate()
                    self.animationTimer = nil
                    self.onUpstrokeComplete(token: token)
                }
            }
        }
        RunLoop.main.add(animationTimer!, forMode: .common)
    }

    private func continueDownstroke(fromFill: Double, remainingTime: TimeInterval, token: UUID) {
        guard guidedRunToken == token else { return }
        let startTime = Date()
        let startFill = fromFill
        let endFill = 0.0

        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] timer in
            guard let self = self, self.guidedRunToken == token, !self.isPaused else {
                timer.invalidate()
                return
            }
            DispatchQueue.main.async {
                let elapsed = Date().timeIntervalSince(startTime)
                let progress = min(elapsed / remainingTime, 1.0)
                self.fill = startFill + (endFill - startFill) * progress
                if progress >= 1.0 {
                    timer.invalidate()
                    self.animationTimer = nil
                    if self.repCount >= self.repTarget { self.finishLesson(); return }
                    self.runUpstroke(token: token)
                }
            }
        }
        RunLoop.main.add(animationTimer!, forMode: .common)
    }

    // MARK: Status text helpers

    private var upstrokeStatusText: String {
        switch exerciseType {
        case .kneeExtension: return "Keep it Coming!"
        case .isometricHold: return "Extend Your Leg!"
        case .kneeFlex:      return "Slide Your Heel!"
        }
    }

    private var downstrokeStatusText: String {
        switch exerciseType {
        case .kneeExtension: return "Keep it Coming!"
        case .isometricHold: return "Lower Slowly"
        case .kneeFlex:      return "Return to Start"
        }
    }

    // MARK: - Simulation (for preview / random testing only)

    func startRandomSimulation() {
        stopRandomSimulation()
        simulationTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let isCorrectSample = Bool.random()
            let sample: SensorSample
            if isCorrectSample {
                sample = SensorSample(
                    kneeAngleDeg: self.targets.kneeTargetDeg + Double.random(in: 0...10),
                    hipDriftDeg: Double.random(in: 0..<self.targets.maxHipDriftDeg),
                    flexActivation: Double.random(in: self.targets.minFlex...1.0)
                )
            } else {
                let failureType = Int.random(in: 0..<3)
                switch failureType {
                case 0:
                    sample = SensorSample(
                        kneeAngleDeg: Double.random(in: 120..<self.targets.kneeTargetDeg),
                        hipDriftDeg: Double.random(in: 0..<self.targets.maxHipDriftDeg),
                        flexActivation: Double.random(in: self.targets.minFlex...1.0)
                    )
                case 1:
                    sample = SensorSample(
                        kneeAngleDeg: self.targets.kneeTargetDeg + Double.random(in: 0...10),
                        hipDriftDeg: self.targets.maxHipDriftDeg + Double.random(in: 1...10),
                        flexActivation: Double.random(in: self.targets.minFlex...1.0)
                    )
                default:
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

        if !inCooldown, s.kneeAngleDeg >= targets.kneeTargetDeg, ok {
            repCount += 1
            inCooldown = true
        } else if inCooldown, s.kneeAngleDeg <= targets.kneeResetDeg {
            inCooldown = false
        }
    }
}
