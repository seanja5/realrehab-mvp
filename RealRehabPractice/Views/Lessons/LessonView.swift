//
//  LessonView.swift
//  RealRehabPractice
//
//  Created by Sean Andrews on 10/28/25.
//

import SwiftUI
import Combine
import CoreBluetooth

private let testMode = true

struct LessonView: View {
    @EnvironmentObject var router: Router
    @Environment(\.scenePhase) private var scenePhase
    let reps: Int?
    let restSec: Int?
    let lessonId: UUID?
    let lessonTitle: String?
    
    @StateObject private var engine: LessonEngine
    @StateObject private var ble = BluetoothManager.shared
    @State private var hasStarted = false
    @State private var isUserPaused = false  // User tapped pause, back, or app went to background
    @State private var showRestartConfirmation = false
    @State private var showRecalibrateSheet = false
    
    // Recalibration on unpause: skip if just re-entered from journey map (they calibrated after "Go!") or if unpause within 10s
    @State private var resumedFromJourneyMap = false
    @State private var lastUnpauseTime: Date? = nil
    
    // Lesson progress (offline resume)
    @State private var elapsedBaseSeconds: Int = 0
    @State private var elapsedReferenceTime: Date? = nil
    @State private var elapsedDisplaySeconds: Int = 0
    @State private var elapsedTimer: Timer? = nil
    
    // Calibration values
    @State private var maxCalibrationValue: Int? = nil
    @State private var restCalibrationValue: Int? = nil
    @State private var isLoadingCalibration = false
    @State private var calibrationError: String? = nil
    
    // Sensor tracking state
    @State private var currentDegreeValue: Int? = nil
    @State private var errorMessage: String? = nil
    @State private var errorEndTime: Date? = nil
    @State private var previousDegreeValue: Int? = nil
    @State private var previousTimestamp: Date? = nil
    @State private var lastRepWasValid: Bool = true
    @State private var hasSpeedError: Bool = false
    @State private var validationTimer: Timer? = nil
    @State private var phaseBeforeError: Phase? = nil  // Store phase before error
    
    // Countdown state after error
    @State private var isCountingDown: Bool = false
    @State private var countdownValue: Int = 3
    @State private var countdownTimer: Timer? = nil
    @State private var showGoMessage: Bool = false
    @State private var goMessageStartTime: Date? = nil
    @State private var isInitialCountdown: Bool = false  // Track if this is initial countdown or after error
    
    // IMU state
    @State private var hasIMUError: Bool = false

    // Countdown ring: wall-clock start time for smooth continuous progress
    @State private var holdStartTime: Date? = nil
    // Between-sets rest ring start time
    @State private var setRestStartTime: Date? = nil

    // Sensor insights: track error count for rep_attempt (repCount + errorCount = attempt)
    @State private var errorCount: Int = 0
    
    // Calibration constants for degree conversion (same as CalibrateDeviceView)
    private let minSensorValue: Int = 185  // 90 degrees (midpoint of 180-190 range)
    private let sensorRange: Int = 115  // 300 - 185 = 115
    private let minDegrees: Double = 90.0
    private let degreeRange: Double = 90.0  // 180 - 90 = 90
    
    // Convert raw flex sensor value to degrees
    private func convertToDegrees(_ sensorValue: Int) -> Int {
        let degrees = minDegrees + (Double(sensorValue - minSensorValue) / Double(sensorRange)) * degreeRange
        return Int(degrees.rounded())
    }
    
    // Computed property for current degree value
    private var currentDegrees: Int? {
        guard let flexValue = ble.currentFlexSensorValue else { return nil }
        return convertToDegrees(flexValue)
    }
    
    // Calculate expected degrees based on box fill percentage
    private func expectedDegreesForFill(_ fill: Double) -> Int? {
        guard let rest = restCalibrationValue,
              let max = maxCalibrationValue else { return nil }
        let range = max - rest
        return rest + Int(Double(range) * fill)
    }
    
    // Calculate vertical position (0.0 = bottom, 1.0 = top) for the user's current degree value
    private func userLinePosition() -> CGFloat? {
        guard let currentDegrees = currentDegreeValue,
              let rest = restCalibrationValue,
              let max = maxCalibrationValue else { return nil }
        
        let range = max - rest
        guard range > 0 else { return nil }
        
        // Calculate position: 0.0 = bottom (rest), 1.0 = top (max)
        let normalizedPosition = Double(currentDegrees - rest) / Double(range)
        // Clamp between 0 and 1
        let clampedPosition = Swift.max(0.0, Swift.min(1.0, normalizedPosition))
        
        return CGFloat(clampedPosition)
    }
    
    // Computed property for current zeroed IMU value
    private var currentIMUValue: Float? {
        ble.currentIMUValue
    }
    
    // Calculate horizontal position of IMU circle on the line
    // Center (0.5) = IMU value of 0
    // Left edge (0.0) = IMU value of +7
    // Right edge (1.0) = IMU value of -7
    private func imuCirclePosition() -> CGFloat? {
        // If lesson hasn't started, keep circle centered (steady and constant)
        guard hasStarted else { return 0.5 }
        
        guard let imuValue = currentIMUValue else { return 0.5 } // Default to center if no value
        
        // Formula: position = 0.5 - (imuValue / 14.0)
        // This maps: +7 -> 0.0 (left), 0 -> 0.5 (center), -7 -> 1.0 (right)
        let position = 0.5 - (Double(imuValue) / 14.0)
        
        // Clamp between 0.0 and 1.0
        let clampedPosition = Swift.max(0.0, Swift.min(1.0, position))
        
        return CGFloat(clampedPosition)
    }
    
    let sets: Int?
    let setRestSec: Int?
    /// Quad Sets: seconds to hold contraction (from plan); ignored for other lessons.
    let holdDurationSec: Int?

    init(reps: Int? = nil, restSec: Int? = nil, lessonId: UUID? = nil, lessonTitle: String? = nil, sets: Int? = nil, setRestSec: Int? = nil, holdDurationSec: Int? = nil) {
        self.reps = reps
        self.restSec = restSec
        self.lessonId = lessonId
        self.lessonTitle = lessonTitle
        self.sets = sets
        self.setRestSec = setRestSec
        self.holdDurationSec = holdDurationSec
        let exerciseType = ExerciseType.from(lessonTitle: lessonTitle)
        let targets = LessonTargets.defaults(for: exerciseType, lessonTitle: lessonTitle)
        let setTotal = sets ?? 1
        let setRestDuration = TimeInterval(setRestSec ?? 60)
        let isometricHold: TimeInterval? = {
            if case .isometricHold = exerciseType {
                return TimeInterval(holdDurationSec ?? 5)
            }
            return nil
        }()
        if let reps = reps, let restSec = restSec {
            let engine = LessonEngine(
                repTarget: reps,
                restDuration: TimeInterval(restSec),
                exerciseType: exerciseType,
                setTotal: setTotal,
                setRestDuration: setRestDuration,
                isometricHoldDurationSec: isometricHold
            )
            engine.targets = targets
            _engine = StateObject(wrappedValue: engine)
        } else {
            let engine = LessonEngine(exerciseType: exerciseType, setTotal: setTotal, setRestDuration: setRestDuration, isometricHoldDurationSec: isometricHold)
            engine.targets = targets
            _engine = StateObject(wrappedValue: engine)
        }
    }
    
    // Set up rep counting callback when engine is available
    private func setupRepCountingCallback() {
        engine.shouldCountRepCallback = {
            if testMode {
                // Every 3rd rep attempt triggers a random error state for demo purposes
                let attempt = self.engine.repCount + self.errorCount + 1
                if attempt % 3 == 0 {
                    DispatchQueue.main.async { self.triggerRandomTestModeError() }
                    return false
                }
                return true
            }
            // Only count if: max was reached and no speed errors occurred during this rep
            return self.lastRepWasValid && !self.hasSpeedError
        }
    }

    private func triggerRandomTestModeError() {
        guard !hasIMUError, errorMessage == nil else { return }
        let choice = Int.random(in: 0...3)
        switch choice {
        case 0:
            recordSensorEvent(type: .maxNotReached, repAttempt: engine.repCount + errorCount, timeSec: Double(currentElapsedSeconds()))
            errorCount += 1
            showError("Extend your leg further!", duration: 3.0)
        case 1:
            recordSensorEvent(type: .tooSlow, repAttempt: engine.repCount + errorCount, timeSec: Double(currentElapsedSeconds()))
            errorCount += 1
            showError("Speed up your Rep!", duration: 3.0)
        case 2:
            recordSensorEvent(type: .tooFast, repAttempt: engine.repCount + errorCount, timeSec: Double(currentElapsedSeconds()))
            errorCount += 1
            showError("Slow down your movement!", duration: 3.0)
        default:
            let driftType: LessonSensorEventType = Bool.random() ? .driftLeft : .driftRight
            recordSensorEvent(type: driftType, repAttempt: engine.repCount + errorCount, timeSec: Double(currentElapsedSeconds()))
            errorCount += 1
            hasIMUError = true
            errorMessage = "Keep your thigh centered"
            errorEndTime = Date().addingTimeInterval(3.0)
            if phaseBeforeError == nil { phaseBeforeError = engine.phase }
            engine.phase = .incorrectHold
            engine.pauseAnimation()
            // No real IMU in test mode — auto-clear after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.clearIMUError()
            }
        }
    }
    
    // Helper function to determine display text
    private func displayText() -> String {
        // All sets fully complete
        if engine.isFullyComplete {
            return "You're Done!"
        }
        // Between-sets rest
        if engine.phase == .setRest {
            return "Rest — Set \(engine.currentSet) of \(engine.setTotal) done"
        }
        
        // User paused (via pause button, back, or background)
        if isUserPaused {
            return "Waiting to Begin..."
        }
        
        // Show error message if present (including IMU errors)
        if let error = errorMessage {
            return error
        }
        
        // Show countdown message
        if isCountingDown {
            return "Starting from rest, begin next rep in \(countdownValue)"
        }
        
        // Show "Go!" message for first 5 seconds after animation starts (even if phase is idle)
        if showGoMessage, let startTime = goMessageStartTime {
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed < 5.0 {
                return "Go!"
            }
        }
        
        // Normal phase-based messages
        switch engine.phase {
        case .idle:
            return hasStarted ? "You've Got It!" : "Waiting…"
        case .incorrectHold:
            return "Not Quite!"
        case .holding:
            return "Hold It! \(engine.holdSecondsRemaining)s"
        case .upstroke:
            switch engine.exerciseType {
            case .kneeFlex:         return "Slide Your Heel!"
            case .isometricHold:    return "Extend Your Leg!"
            case .straightLegRaise: return "Lift Your Leg!"
            case .anklePumps:       return "Pump Up!"
            default:                return "Extend Your Leg!"
            }
        case .downstroke:
            switch engine.exerciseType {
            case .kneeFlex:         return "Return to Start"
            case .anklePumps:       return "Pump Down!"
            default:                return "Lower Slowly"
            }
        case .setRest:
            return "Rest — Set \(engine.currentSet) of \(engine.setTotal) done"
        }
    }
    
    // Exercise motion verb shown in the card header banner
    private func exerciseVerb() -> String {
        switch engine.exerciseType {
        case .isometricHold:    return "TIGHTEN"
        case .kneeFlex:         return "SLIDE"
        case .straightLegRaise: return "LIFT"
        case .anklePumps:       return "PUMP"
        default:                return "EXTEND"
        }
    }

    // Helper function to determine text color
    private func textColor() -> Color {
        return .primary
    }
    
    // Helper function to determine background color
    private func backgroundColor() -> Color {
        // All sets fully complete or between-sets rest — subtle green tint
        if engine.isFullyComplete || engine.phase == .setRest {
            return Color.green.opacity(0.05)
        }
        // User paused - neutral gray
        if isUserPaused {
            return Color.gray.opacity(0.12)
        }
        // Error states — very light red base (gradient overlay provides color)
        if hasIMUError || errorMessage != nil {
            return Color.red.opacity(0.04)
        }
        if engine.phase == .incorrectHold {
            return Color.red.opacity(0.04)
        }
        // Countdown / idle — neutral
        if isCountingDown || engine.phase == .idle {
            return Color.gray.opacity(0.12)
        }
        // Active phases — subtle base (gradient overlay will appear on top)
        return Color.brandDarkBlue.opacity(0.05)
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // Progress (non-interactive)
            VStack(spacing: 6) {
                ProgressView(value: min(Double(engine.repCount) / Double(engine.repTarget), 1.0))
                    .progressViewStyle(.linear)
                    .tint(Color.brandDarkBlue)
                    .padding(.horizontal, 16)

                HStack(spacing: 0) {
                    HStack(spacing: 4) {
                        Text("\(engine.repCount)")
                            .font(.rrBody.bold())
                            .foregroundStyle(Color.brandDarkBlue)
                        Text("/ \(engine.repTarget)")
                            .font(.rrBody)
                            .foregroundStyle(.secondary)
                        Text("reps")
                            .font(.rrCaption)
                            .foregroundStyle(.secondary)
                        if engine.setTotal > 1 {
                            Text("· Set \(min(engine.currentSet, engine.setTotal)) of \(engine.setTotal)")
                                .font(.rrCaption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if hasStarted && elapsedDisplaySeconds > 0 {
                        Text(formatElapsed(elapsedDisplaySeconds))
                            .font(.rrCaption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16)
            }
            .padding(.top, 4)

            // Feedback card
            ZStack {
                // Base rounded panel
                RoundedRectangle(cornerRadius: 20)
                    .fill(backgroundColor())

                // Green gradient — correct active phases (upstroke, downstroke, holding, setRest, completed)
                if !isUserPaused && (engine.phase == .upstroke || engine.phase == .downstroke || engine.phase == .holding || engine.phase == .setRest || engine.isFullyComplete) {
                    GeometryReader { geo in
                        let h = geo.size.height
                        VStack {
                            Spacer()
                            LinearGradient(
                                colors: [
                                    Color(red: 0.10, green: 0.80, blue: 0.15).opacity(0.38),
                                    Color(red: 0.04, green: 0.50, blue: 0.08).opacity(0.60)
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                            .frame(height: max(0, h * max(0.08, engine.fill)))
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .allowsHitTesting(false)
                }

                // Light-red gradient — error / incorrect states
                if !isUserPaused && (hasIMUError || errorMessage != nil || engine.phase == .incorrectHold) {
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.25, blue: 0.25).opacity(0.35),
                            Color(red: 0.75, green: 0.08, blue: 0.08).opacity(0.55)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .allowsHitTesting(false)
                }

                // Horizontal blue line indicator showing user's current position (always visible)
                if let linePosition = userLinePosition() {
                    GeometryReader { geo in
                        let boxHeight = geo.size.height
                        let yPosition = boxHeight * (1.0 - linePosition)
                        Rectangle()
                            .fill(Color.brandDarkBlue)
                            .frame(width: geo.size.width * 0.9)
                            .frame(height: 3)
                            .position(x: geo.size.width / 2, y: yPosition)
                        if let circlePosition = imuCirclePosition() {
                            let xPosition = geo.size.width * 0.05 + (geo.size.width * 0.9 * circlePosition)
                            Circle()
                                .fill(Color.brandDarkBlue)
                                .frame(width: 14, height: 14)
                                .position(x: xPosition, y: yPosition)
                        }
                    }
                    .allowsHitTesting(false)
                } else {
                    GeometryReader { geo in
                        let yPosition = geo.size.height * 0.5
                        if let circlePosition = imuCirclePosition() {
                            let xPosition = geo.size.width * 0.05 + (geo.size.width * 0.9 * circlePosition)
                            Circle()
                                .fill(Color.brandDarkBlue)
                                .frame(width: 14, height: 14)
                                .position(x: xPosition, y: yPosition)
                        }
                    }
                    .allowsHitTesting(false)
                }

                // Isometric hold: circular countdown ring overlay (replaces plain text for holding phase)
                if engine.phase == .holding, case .isometricHold = engine.exerciseType {
                    TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                        let elapsed = holdStartTime.map { context.date.timeIntervalSince($0) } ?? 0
                        let progress = max(0, CGFloat(1.0 - elapsed / engine.holdDuration))
                        ZStack {
                            Circle()
                                .stroke(Color.primary.opacity(0.15), lineWidth: 8)
                                .frame(width: 88, height: 88)
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(Color.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .frame(width: 88, height: 88)
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 1) {
                                Text("\(engine.holdSecondsRemaining)")
                                    .font(.rrTitle.bold())
                                    .foregroundStyle(.primary)
                                Text("sec")
                                    .font(.rrCaption)
                                    .foregroundStyle(.primary.opacity(0.7))
                            }
                        }
                    }
                    .onAppear { holdStartTime = Date() }
                    .onDisappear { holdStartTime = nil }
                    .allowsHitTesting(false)
                } else if engine.phase == .setRest {
                    // Between-sets rest: same-style ring countdown
                    let setRestDur = TimeInterval(setRestSec ?? 60)
                    TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
                        let elapsed = setRestStartTime.map { context.date.timeIntervalSince($0) } ?? 0
                        let progress = max(0, CGFloat(1.0 - elapsed / setRestDur))
                        ZStack {
                            Circle()
                                .stroke(Color.primary.opacity(0.15), lineWidth: 8)
                                .frame(width: 88, height: 88)
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(Color.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                .frame(width: 88, height: 88)
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 2) {
                                Text("\(engine.setRestSecondsRemaining)")
                                    .font(.rrTitle.bold())
                                    .foregroundStyle(.primary)
                                Text("rest")
                                    .font(.rrCaption)
                                    .foregroundStyle(.primary.opacity(0.7))
                            }
                        }
                    }
                    .onAppear { setRestStartTime = Date() }
                    .onDisappear { setRestStartTime = nil }
                    .allowsHitTesting(false)
                } else {
                    // Center text — countdown, error, phase cues
                    Text(displayText())
                        .font(.rrHeadline)
                        .foregroundStyle(textColor())
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Exercise identity banner — top of card
                VStack {
                    HStack(spacing: 6) {
                        Image(systemName: ACLJourneyModels.lessonIconSystemName(for: lessonTitle ?? ""))
                            .font(.system(size: 11, weight: .semibold))
                        Text(exerciseVerb())
                            .font(.rrCaption.bold())
                            .tracking(1.5)
                    }
                    .foregroundStyle(Color.brandDarkBlue.opacity(errorMessage != nil ? 0.0 : 0.65))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.brandDarkBlue.opacity(errorMessage != nil ? 0.0 : 0.07))
                    .clipShape(Capsule())
                    .padding(.top, 14)
                    Spacer()
                }
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)

            // Bottom controls row: Range pill (left) + Pause/Restart buttons (right)
            HStack(alignment: .center, spacing: 12) {
                // Left: Calibration range pill
                if let maxCal = maxCalibrationValue, let restCal = restCalibrationValue {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.and.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.brandDarkBlue.opacity(0.6))
                        Text("Range: \(restCal)°–\(maxCal)°")
                            .font(.rrCaption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(Color.brandDarkBlue.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                Spacer()

                // Right: Pause/Restart buttons (only when lesson has started)
                if hasStarted {
                    HStack(spacing: 10) {
                        Button {
                            if isUserPaused {
                                resumeLesson()
                            } else {
                                pauseLesson()
                            }
                        } label: {
                            Image(systemName: isUserPaused ? "play.fill" : "pause.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(isUserPaused ? .white : Color.brandDarkBlue)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(isUserPaused ? Color.brandDarkBlue : Color.clear)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.brandDarkBlue, lineWidth: 2)
                                        )
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            showRestartConfirmation = true
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.brandDarkBlue)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(Color.clear)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.brandDarkBlue, lineWidth: 2)
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            // Single primary action button
            PrimaryButton(
                title: !hasStarted ? "Begin Lesson" : (engine.isFullyComplete ? "Complete Session!" : "Lesson Running"),
                isDisabled: hasStarted && !engine.isFullyComplete,
                useLargeFont: true
            ) {
                if !hasStarted {
                    hasStarted = true
                    elapsedBaseSeconds = 0
                    elapsedReferenceTime = Date()
                    startElapsedTimer()
                    ble.zeroIMUValue()
                    engine.reset()
                    setupRepCountingCallback()
                    startSensorValidation()
                    startCountdown(isInitial: true)
                    if let lessonId = lessonId {
                        LocalLessonProgressStore.shared.saveDraft(lessonId: lessonId, repsCompleted: 0, repsTarget: engine.repTarget, elapsedSeconds: 0, status: "inProgress")
                        enqueueAndSyncLessonProgress(lessonId: lessonId, repsCompleted: 0, repsTarget: engine.repTarget, elapsedSeconds: 0, status: "inProgress")
                        startSensorInsightsCollection(lessonId: lessonId)
                    }
                } else if engine.isFullyComplete {
                    engine.stopGuidedSimulation()
                    persistAndCompleteLesson()
                    router.go(.assessment(lessonId: lessonId))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .safeAreaPadding(.bottom)
        }
        .rrPageBackground()
        .overlay {
            if showRestartConfirmation {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture { showRestartConfirmation = false }
                    .overlay {
                        VStack(spacing: 20) {
                            Text("Restart this lesson?")
                                .font(.rrTitle)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                            
                            PrimaryButton(title: "Restart", useLargeFont: true) {
                                restartLesson()
                                showRestartConfirmation = false
                            }
                            .padding(.horizontal, 24)
                            
                            SecondaryButton(title: "Close") {
                                showRestartConfirmation = false
                            }
                            .padding(.horizontal, 24)
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(uiColor: .systemBackground))
                                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 8)
                        )
                    }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .swipeToGoBack(onBack: {
            if hasStarted { pauseLesson() }
            router.reset(to: .journeyMap)
        })
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(lessonTitle ?? "Lesson")
                    .font(.rrHeadline)
            }
            ToolbarItem(placement: .topBarLeading) {
                BackButton {
                    if hasStarted {
                        pauseLesson()
                    }
                    router.reset(to: .journeyMap)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                BluetoothStatusIndicator()
            }
        }
        .onAppear {
            loadCalibrationData()
            restoreLessonProgressIfNeeded()
        }
        .onDisappear {
            if hasStarted {
                if !isUserPaused {
                    pauseLesson()
                } else {
                    persistLessonDraft(enqueueForSync: true)
                }
            } else {
                engine.stopGuidedSimulation()
                stopSensorValidation()
                countdownTimer?.invalidate()
                countdownTimer = nil
                stopElapsedTimer()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                if hasStarted && !isUserPaused {
                    pauseLesson()
                } else {
                    persistLessonDraft(enqueueForSync: true)
                }
            }
        }
        .onChange(of: engine.repCount) { _, newCount in
            // Skip when repCount resets to 0 at start of next set — don't overwrite prior progress
            guard newCount > 0 else { return }
            persistLessonDraft()
            LessonSensorInsightsCollector.shared.saveDraftIntermediate(
                repsCompleted: newCount,
                totalDurationSec: currentElapsedSeconds()
            )
            // Sync to Supabase on every rep so PT sees progress in real time
            if let lessonId = lessonId {
                let status = engine.isFullyComplete ? "completed" : "inProgress"
                enqueueAndSyncLessonProgress(lessonId: lessonId, repsCompleted: newCount, repsTarget: engine.repTarget, elapsedSeconds: currentElapsedSeconds(), status: status)
            }
        }
        .onChange(of: ble.currentFlexSensorValue) { oldValue, newValue in
            guard !testMode, let value = newValue else { return }
            currentDegreeValue = convertToDegrees(value)
        }
        .onChange(of: engine.phase) { oldPhase, newPhase in
            // Reset validation flags at start of new upstroke
            if newPhase == .upstroke && oldPhase != .upstroke {
                lastRepWasValid = false
                hasSpeedError = false
            }
        }
        .onChange(of: engine.fill) { oldValue, newValue in
            // Check when box reaches full for max/flexion validation
            guard !testMode else { return }
            if newValue >= 0.99 && oldValue < 0.99 && engine.phase == .upstroke {
                if case .kneeFlex = engine.exerciseType {
                    // Heel slides: validate flexion target was reached
                    if let currentDegrees = currentDegreeValue {
                        let target = engine.targets.flexionTargetDeg
                        if Double(currentDegrees) > target {
                            recordSensorEvent(type: .rangeNotReached, repAttempt: engine.repCount + errorCount, timeSec: Double(currentElapsedSeconds()))
                            errorCount += 1
                            lastRepWasValid = false
                        } else {
                            lastRepWasValid = true
                        }
                    }
                } else {
                    if let currentDegrees = currentDegreeValue, let maxDegrees = maxCalibrationValue {
                        validateMaxReached(currentDegrees: currentDegrees, maxDegrees: maxDegrees)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showRecalibrateSheet) {
            NavigationStack {
                CalibrateDeviceView(fromUnpause: true) {
                    showRecalibrateSheet = false
                    resumeAfterRecalibration()
                }
            }
            .environmentObject(router)
            .transition(.opacity)
        }
        .bluetoothPopupOverlay()
    }
    
    // MARK: - Lesson Progress (Offline Resume)

    private func formatElapsed(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%dm %ds", m, s)
    }

    private func currentElapsedSeconds() -> Int {
        guard let ref = elapsedReferenceTime else { return elapsedBaseSeconds }
        return elapsedBaseSeconds + Int(Date().timeIntervalSince(ref))
    }

    private func startElapsedTimer() {
        stopElapsedTimer()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task { @MainActor in
                elapsedDisplaySeconds = currentElapsedSeconds()
                persistLessonDraft(enqueueForSync: true)
            }
        }
        RunLoop.main.add(elapsedTimer!, forMode: .common)
        elapsedDisplaySeconds = currentElapsedSeconds()
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    private func pauseLesson() {
        guard !isUserPaused else { return }
        isUserPaused = true
        elapsedBaseSeconds = currentElapsedSeconds()
        elapsedReferenceTime = nil
        stopElapsedTimer()
        countdownTimer?.invalidate()
        countdownTimer = nil
        stopSensorValidation()
        engine.pauseAnimation()
        persistLessonDraft(enqueueForSync: true)
        LessonSensorInsightsCollector.shared.pauseAndPersistDraft(
            repsCompleted: engine.repCount,
            totalDurationSec: currentElapsedSeconds()
        )
    }

    private func resumeLesson() {
        guard isUserPaused else { return }
        let now = Date()
        // Unpause within 10 seconds of last unpause → skip calibration (accidental pause)
        if let last = lastUnpauseTime, now.timeIntervalSince(last) < 10 {
            performResume(loadCalibration: false)
            return
        }
        // Just re-entered from journey map (calibrated after "Go!") → skip calibration this once
        if resumedFromJourneyMap {
            resumedFromJourneyMap = false
            performResume(loadCalibration: false)
            return
        }
        // Otherwise require recalibration (e.g. stayed on lesson screen and may have moved)
        showRecalibrateSheet = true
    }

    /// Shared resume logic. Call after calibration sheet (with loadCalibration: true) or when skipping calibration.
    private func performResume(loadCalibration: Bool) {
        guard isUserPaused else { return }
        if let lid = lessonId {
            if !LessonSensorInsightsCollector.shared.resumeFromDraft(lessonId: lid) {
                startSensorInsightsCollection(lessonId: lid)
            }
        }
        if loadCalibration {
            loadCalibrationData()
        }
        isUserPaused = false
        elapsedReferenceTime = Date()
        startElapsedTimer()
        startSensorValidation()
        startCountdown(isInitial: false)
        lastUnpauseTime = Date()
    }

    private func resumeAfterRecalibration() {
        performResume(loadCalibration: true)
    }

    private func restartLesson() {
        engine.stopGuidedSimulation()
        stopSensorValidation()
        countdownTimer?.invalidate()
        countdownTimer = nil
        stopElapsedTimer()
        engine.reset()
        hasStarted = false
        isUserPaused = false
        elapsedBaseSeconds = 0
        elapsedReferenceTime = nil
        elapsedDisplaySeconds = 0
        errorCount = 0
        lastUnpauseTime = nil
        resumedFromJourneyMap = false
        if let lessonId = lessonId {
            LocalLessonProgressStore.shared.clearDraft(lessonId: lessonId)
            clearLessonProgressOnServerAndCache(lessonId: lessonId)
        }
        LessonSensorInsightsCollector.shared.stop()
    }

    /// When patient restarts, delete this lesson's progress on the server and invalidate cache so journey map and PT see it cleared.
    private func clearLessonProgressOnServerAndCache(lessonId: UUID) {
        Task {
            guard let profile = try? await AuthService.myProfile(),
                  let patientProfileId = try? await PatientService.myPatientProfileId(profileId: profile.id) else { return }
            OutboxSyncManager.shared.enqueueLessonProgressClear(patientProfileId: patientProfileId, lessonId: lessonId)
            await OutboxSyncManager.shared.processQueueIfOnline()
            await CacheService.shared.invalidate(CacheKey.lessonProgress(patientProfileId: patientProfileId))
            await CacheService.shared.invalidate(CacheKey.completionDates(patientProfileId: patientProfileId))
        }
    }

    private func restoreLessonProgressIfNeeded() {
        guard let lessonId = lessonId else { return }
        guard let draft = LocalLessonProgressStore.shared.loadDraft(lessonId: lessonId) else { return }
        guard draft.status != "completed" else { return }
        engine.restoreSession(repCount: draft.repsCompleted)
        elapsedBaseSeconds = draft.elapsedSeconds
        elapsedReferenceTime = nil
        elapsedDisplaySeconds = draft.elapsedSeconds
        hasStarted = true
        isUserPaused = true
        setupRepCountingCallback()
        engine.phase = .idle
        engine.fill = 0.0
        // User re-entered from journey map (Go! → calibrate → directions → lesson); they just calibrated, so first unpause should skip recalibration
        resumedFromJourneyMap = true
    }

    private func persistLessonDraft(enqueueForSync: Bool = false) {
        guard let lessonId = lessonId else { return }
        let repsCompleted = engine.repCount
        let repsTarget = engine.repTarget
        let elapsed = currentElapsedSeconds()
        let status = repsCompleted >= repsTarget ? "completed" : "inProgress"
        LocalLessonProgressStore.shared.saveDraft(lessonId: lessonId, repsCompleted: repsCompleted, repsTarget: repsTarget, elapsedSeconds: elapsed, status: status)
        if enqueueForSync {
            enqueueAndSyncLessonProgress(lessonId: lessonId, repsCompleted: repsCompleted, repsTarget: repsTarget, elapsedSeconds: elapsed, status: status)
        }
    }

    private func persistAndCompleteLesson() {
        guard let lessonId = lessonId else { return }
        let repsCompleted = engine.repCount
        let repsTarget = engine.repTarget
        let elapsed = currentElapsedSeconds()
        LocalLessonProgressStore.shared.saveDraft(lessonId: lessonId, repsCompleted: repsCompleted, repsTarget: repsTarget, elapsedSeconds: elapsed, status: "completed")
        enqueueAndSyncLessonProgress(lessonId: lessonId, repsCompleted: repsCompleted, repsTarget: repsTarget, elapsedSeconds: elapsed, status: "completed")
        LocalLessonProgressStore.shared.clearDraft(lessonId: lessonId)
        stopElapsedTimer()
        finishSensorInsightsCollection(completed: true)
    }

    /// Enqueue lesson progress for Supabase sync and process immediately when online.
    private func enqueueAndSyncLessonProgress(lessonId: UUID, repsCompleted: Int, repsTarget: Int, elapsedSeconds: Int, status: String) {
        Task {
            guard let profile = try? await AuthService.myProfile(),
                  let patientProfileId = try? await PatientService.myPatientProfileId(profileId: profile.id) else { return }
            OutboxSyncManager.shared.enqueueLessonProgress(patientProfileId: patientProfileId, lessonId: lessonId, repsCompleted: repsCompleted, repsTarget: repsTarget, elapsedSeconds: elapsedSeconds, status: status)
            await OutboxSyncManager.shared.processQueueIfOnline()
        }
    }

    // MARK: - Calibration Loading
    
    private func loadCalibrationData() {
        if testMode {
            restCalibrationValue = 90
            maxCalibrationValue = 180
            return
        }
        guard let peripheral = ble.connectedPeripheral else {
            calibrationError = "No device connected. Please pair a device first."
            return
        }
        
        let bluetoothIdentifier = peripheral.identifier.uuidString
        
        isLoadingCalibration = true
        Task {
            do {
                let calibration = try await TelemetryService.getMostRecentCalibration(bluetoothIdentifier: bluetoothIdentifier)
                await MainActor.run {
                    maxCalibrationValue = calibration.maxDegrees
                    restCalibrationValue = calibration.restDegrees
                    isLoadingCalibration = false
                    
                    if calibration.maxDegrees == nil || calibration.restDegrees == nil {
                        calibrationError = "No calibration data found. Please calibrate your device first."
                    }
                }
            } catch {
                await MainActor.run {
                    calibrationError = "Failed to load calibration: \(error.localizedDescription)"
                    isLoadingCalibration = false
                }
            }
        }
    }
    
    // MARK: - Sensor Validation
    
    private func startSensorValidation() {
        stopSensorValidation()
        validationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard self.hasStarted else { return }
            self.validateMovement()
        }
    }
    
    private func stopSensorValidation() {
        validationTimer?.invalidate()
        validationTimer = nil
    }
    
    private func validateMovement() {
        // Stop validation if all reps are completed
        guard engine.repCount < engine.repTarget else { return }

        // TEST MODE: simulate the sensor line tracking the fill; skip all error checks
        if testMode {
            currentDegreeValue = expectedDegreesForFill(engine.fill) ?? currentDegreeValue
            lastRepWasValid = true
            return
        }
        
        // Check if error display time has expired (only for non-IMU errors)
        if let errorEnd = errorEndTime, Date() >= errorEnd, !hasIMUError {
            clearError()
        }
        
        // Validate IMU continuously when lesson is running
        if hasStarted {
            validateIMU()
        }
        
        // Validate isometric hold: check angle stays within 15° of max calibration during .holding phase
        if hasStarted, !engine.isPaused, engine.phase == .holding,
           let currentDegrees = currentDegreeValue,
           let maxCal = maxCalibrationValue {
            if case .isometricHold = engine.exerciseType {
                let failThreshold = Double(maxCal) - 15.0
                if Double(currentDegrees) < failThreshold {
                    recordSensorEvent(type: .holdBroken, repAttempt: engine.repCount + errorCount, timeSec: Double(currentElapsedSeconds()))
                    errorCount += 1
                    showError("Make sure you hold your leg!", duration: 3.0)
                }
            }
        }

        // Only validate flex sensor movement if lesson is running and not paused
        guard hasStarted,
              !engine.isPaused,
              errorMessage == nil,
              let currentDegrees = currentDegreeValue,
              let rest = restCalibrationValue,
              let max = maxCalibrationValue,
              (engine.phase == .upstroke || engine.phase == .downstroke) else {
            return
        }

        let expectedDegrees = expectedDegreesForFill(engine.fill)

        // Validate movement speed only if we have previous data
        if let expected = expectedDegrees, let previous = previousDegreeValue, let prevTime = previousTimestamp {
            let timeElapsed = Date().timeIntervalSince(prevTime)
            if timeElapsed > 0 {
                validateMovementSpeed(currentDegrees: currentDegrees, expectedDegrees: expected, previousDegrees: previous, timeElapsed: timeElapsed, rest: rest, max: max)
            }
        }
        
        // Update previous values
        previousDegreeValue = currentDegrees
        previousTimestamp = Date()
    }
    
    private func validateIMU() {
        // Stop IMU validation if all reps are completed
        guard engine.repCount < engine.repTarget else {
            return
        }
        
        guard let imuValue = currentIMUValue else { return }
        
        let absIMUValue = abs(imuValue)
        let threshold: Float = 7.0  // Range is now -7 to +7
        
        // Check if IMU is out of range
        if absIMUValue > threshold {
            // Trigger error if not already showing
            if !hasIMUError {
                showIMUError()
            }
        } else {
            // Clear error immediately if back in range
            if hasIMUError {
                clearIMUError()
            }
        }
    }
    
    private func showIMUError() {
        guard !hasIMUError else { return } // Don't override if already showing

        let repAttempt = engine.repCount + errorCount
        let timeSec = Double(currentElapsedSeconds())
        let driftType: LessonSensorEventType = (currentIMUValue ?? 0) > 0 ? .driftLeft : .driftRight
        recordSensorEvent(type: driftType, repAttempt: repAttempt, timeSec: timeSec)
        errorCount += 1

        hasIMUError = true
        errorMessage = "Keep your thigh centered"
        errorEndTime = Date().addingTimeInterval(4.0) // Set timeout, but clear immediately when back in range

        // Store current phase before showing error
        if phaseBeforeError == nil {
            phaseBeforeError = engine.phase
        }

        engine.phase = .incorrectHold
        engine.pauseAnimation()
    }
    
    private func clearIMUError() {
        guard hasIMUError else { return }
        
        hasIMUError = false
        errorMessage = nil
        errorEndTime = nil
        phaseBeforeError = nil
        
        // Start countdown like other errors
        startCountdown()
        
        // Reset after a delay to allow new validation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Animation will resume after countdown
        }
    }
    
    private func validateMovementSpeed(currentDegrees: Int, expectedDegrees: Int, previousDegrees: Int, timeElapsed: TimeInterval, rest: Int, max: Int) {
        // Calculate expected rate: total range divided by time (using dynamic restDuration from engine)
        // restDuration is split evenly between upstroke and downstroke, so each stroke takes restDuration / 2.0 seconds
        let strokeDuration = engine.restDuration / 2.0
        let totalRange = Double(abs(max - rest))
        let expectedRate = totalRange / strokeDuration // degrees per second
        
        // Calculate actual rate of change
        let actualDegreeChange = abs(currentDegrees - previousDegrees)
        let actualRate = Double(actualDegreeChange) / timeElapsed
        
        // Calculate position error (how far off from expected position)
        let positionError = Double(abs(currentDegrees - expectedDegrees))
        let toleranceRange = 25.0 // 25-degree tolerance
        
        // Check if position is way off (beyond tolerance)
        if positionError > toleranceRange {
            // Check direction of error to determine if too fast or too slow
            if currentDegrees > expectedDegrees + Int(toleranceRange) {
                // Ahead of schedule - moving too fast
                if actualRate > expectedRate * 1.5 {
                    recordSensorEvent(type: .tooFast, repAttempt: engine.repCount + errorCount, timeSec: Double(currentElapsedSeconds()))
                    errorCount += 1
                    showError("Slow down your movement!", duration: 4.0)
                    hasSpeedError = true
                }
            } else if currentDegrees < expectedDegrees - Int(toleranceRange) {
                // Behind schedule - moving too slow
                if actualRate < expectedRate * 0.5 {
                    recordSensorEvent(type: .tooSlow, repAttempt: engine.repCount + errorCount, timeSec: Double(currentElapsedSeconds()))
                    errorCount += 1
                    showError("Speed up your Rep!", duration: 4.0)
                    hasSpeedError = true
                }
            }
        } else {
            // Within acceptable range
            hasSpeedError = false
        }
    }
    
    private func validateMaxReached(currentDegrees: Int, maxDegrees: Int) {
        let tolerance = 10 // 10 degree tolerance (can be 10 degrees below or above)
        if currentDegrees < (maxDegrees - tolerance) || currentDegrees > (maxDegrees + tolerance) {
            recordSensorEvent(type: .maxNotReached, repAttempt: engine.repCount + errorCount, timeSec: Double(currentElapsedSeconds()))
            errorCount += 1
            showError("Extend your leg further!", duration: 4.0)
            lastRepWasValid = false
        } else {
            lastRepWasValid = true
        }
    }

    private func recordSensorEvent(type: LessonSensorEventType, repAttempt: Int, timeSec: Double) {
        LessonSensorInsightsCollector.shared.recordEvent(type: type, repAttempt: repAttempt, timeSec: timeSec)
    }

    private func startSensorInsightsCollection(lessonId: UUID) {
        Task {
            guard let profile = try? await AuthService.myProfile(),
                  let patientProfileId = try? await PatientService.myPatientProfileId(profileId: profile.id),
                  let ptProfileId = try? await PatientService.getPTProfileId(patientProfileId: patientProfileId) else { return }
            await MainActor.run {
                LessonSensorInsightsCollector.shared.start(
                    lessonId: lessonId,
                    patientProfileId: patientProfileId,
                    ptProfileId: ptProfileId,
                    repsTarget: engine.repTarget
                )
            }
        }
    }

    private func finishSensorInsightsCollection(completed: Bool) {
        LessonSensorInsightsCollector.shared.updateProgress(
            repsCompleted: engine.repCount,
            totalDurationSec: currentElapsedSeconds()
        )
        LessonSensorInsightsCollector.shared.finishAndSaveDraft(completed: completed)
    }
    
    private func showError(_ message: String, duration: TimeInterval) {
        guard errorMessage == nil && !hasIMUError else { return } // Don't override existing error
        
        errorMessage = message
        errorEndTime = Date().addingTimeInterval(duration)
        
        // Store current phase before showing error
        if phaseBeforeError == nil {
            phaseBeforeError = engine.phase
        }
        
        engine.phase = .incorrectHold
        engine.pauseAnimation()
        
        // Auto-resume after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.clearError()
        }
    }
    
    private func clearError() {
        guard !hasIMUError else { return } // Don't clear if IMU error is active
        
        errorMessage = nil
        errorEndTime = nil
        phaseBeforeError = nil
        
        // Start countdown instead of immediately restarting
        startCountdown()
        
        // Reset speed error flag after a delay to allow new validation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.hasSpeedError = false
        }
    }
    
    // Start 3-second countdown before restarting animation
    private func startCountdown(isInitial: Bool = false) {
        // Stop any existing countdown timer
        countdownTimer?.invalidate()
        
        isCountingDown = true
        isInitialCountdown = isInitial
        countdownValue = 3
        engine.phase = .idle  // Set to idle to show gray box
        
        // Use a timer that updates every second for live countdown
        var remainingSeconds = 3
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            remainingSeconds -= 1
            
            if remainingSeconds > 0 {
                // Update countdown value on main thread to trigger view update
                DispatchQueue.main.async {
                    self.countdownValue = remainingSeconds
                }
            } else {
                // Countdown finished
                timer.invalidate()
                
                DispatchQueue.main.async {
                    self.countdownTimer = nil
                    self.isCountingDown = false
                    // Start animation with "Go!" message
                    self.showGoMessage = true
                    self.goMessageStartTime = Date()
                    
                    // Use different start method based on whether this is initial or after error/resume
                    if self.isInitialCountdown {
                        self.engine.startGuidedSimulation(skipInitialWait: true)
                    } else {
                        self.engine.startOrRestartFromBottom()
                    }
                    
                    // Clear "Go!" message after 5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        self.showGoMessage = false
                    }
                }
            }
        }
        
        // Add timer to run loop to ensure it fires even during scrolling
        if let timer = countdownTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
}
