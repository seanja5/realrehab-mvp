//
//  LessonView.swift
//  RealRehabPractice
//
//  Created by Sean Andrews on 10/28/25.
//

import SwiftUI
import Combine
import CoreBluetooth

struct LessonView: View {
    @EnvironmentObject var router: Router
    @Environment(\.scenePhase) private var scenePhase
    let reps: Int?
    let restSec: Int?
    let lessonId: UUID?
    
    @StateObject private var engine: LessonEngine
    @StateObject private var ble = BluetoothManager.shared
    @State private var hasStarted = false
    @State private var isUserPaused = false  // User tapped pause, back, or app went to background
    @State private var showRestartConfirmation = false
    
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
    
    init(reps: Int? = nil, restSec: Int? = nil, lessonId: UUID? = nil) {
        self.reps = reps
        self.restSec = restSec
        self.lessonId = lessonId
        // Initialize engine with parameters if provided (for Knee Extension only)
        if let reps = reps, let restSec = restSec {
            // Convert restSec (Int seconds) to TimeInterval
            let engine = LessonEngine(repTarget: reps, restDuration: TimeInterval(restSec))
            _engine = StateObject(wrappedValue: engine)
        } else {
            _engine = StateObject(wrappedValue: LessonEngine())
        }
    }
    
    // Set up rep counting callback when engine is available
    private func setupRepCountingCallback() {
        engine.shouldCountRepCallback = {
            // Only count if: max was reached and no speed errors occurred during this rep
            return self.lastRepWasValid && !self.hasSpeedError
        }
    }
    
    // Helper function to determine display text
    private func displayText() -> String {
        // Check if all reps are completed - show completion message
        if engine.repCount >= engine.repTarget {
            return "You're Done!"
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
            // Only show "Waiting…" if lesson hasn't started yet
            return hasStarted ? "You've Got It!" : "Waiting…"
        case .incorrectHold:
            return "Not Quite!"
        case .upstroke, .downstroke:
            return "You've Got It!"
        }
    }
    
    // Helper function to determine text color
    private func textColor() -> Color {
        if errorMessage != nil {
            return .white
        }
        if isCountingDown {
            return .primary
        }
        if engine.phase == .incorrectHold {
            return .white
        }
        return .primary
    }
    
    // Helper function to determine background color
    private func backgroundColor() -> Color {
        // If all reps are completed, show full green
        if engine.repCount >= engine.repTarget {
            return Color.green.opacity(0.25)
        }
        
        // User paused - gray
        if isUserPaused {
            return Color.gray.opacity(0.3)
        }
        
        // Show red if there's an error (IMU error or any other error)
        if hasIMUError || errorMessage != nil {
            return Color.red
        }
        if isCountingDown {
            return Color.gray.opacity(0.3)
        }
        if engine.phase == .incorrectHold {
            return Color.red
        }
        if engine.phase == .idle {
            return Color.gray.opacity(0.3)
        }
        return Color.green.opacity(0.25)
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // Title
            Text("Knee Extension")
                .font(.rrHeadline)
                .padding(.top, 8)
            
            // Progress (non-interactive)
            VStack(spacing: 8) {
                ProgressView(value: min(Double(engine.repCount) / Double(engine.repTarget), 1.0))
                    .progressViewStyle(.linear)
                    .tint(Color.brandDarkBlue)
                    .padding(.horizontal, 16)
                
                VStack(spacing: 4) {
                    Text("Repetitions: \(engine.repCount)/\(engine.repTarget)")
                        .font(.rrCallout)
                    if hasStarted && elapsedDisplaySeconds > 0 {
                        Text(formatElapsed(elapsedDisplaySeconds))
                            .font(.rrCaption)
                            .foregroundStyle(.secondary)
                    }
                }
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
                    .fill(backgroundColor())
                
                // Green fill overlay during strokes or when completed (hidden when user paused)
                if !isUserPaused && (engine.phase == .upstroke || engine.phase == .downstroke || engine.repCount >= engine.repTarget) {
                    GeometryReader { geo in
                        let h = geo.size.height
                        // Bottom-anchored fill whose height animates with engine.fill
                        // When completed, fill stays at 1.0 (fully green)
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
                
                // Horizontal blue line indicator showing user's current position (always visible)
                if let linePosition = userLinePosition() {
                    GeometryReader { geo in
                        let boxHeight = geo.size.height
                        let yPosition = boxHeight * (1.0 - linePosition) // Flip Y axis (0 = bottom)
                        
                        Rectangle()
                            .fill(Color.brandDarkBlue)
                            .frame(width: geo.size.width * 0.9) // 90% of box width
                            .frame(height: 3) // 3 point thick line
                            .position(x: geo.size.width / 2, y: yPosition)
                        
                        // IMU circle indicator on the horizontal line
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
                    // Show IMU circle even when no flex sensor line is visible (default to center)
                    GeometryReader { geo in
                        let boxHeight = geo.size.height
                        let yPosition = boxHeight * 0.5 // Center vertically
                        
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
                
                // Center text - show countdown, error messages, "Go!", or default text
                Text(displayText())
                    .font(.rrTitle)
                    .foregroundStyle(textColor())
            }
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Spacer(minLength: 16)
            
            // Bottom section with calibration reference and live data
            HStack(alignment: .bottom, spacing: 12) {
                // Left: Calibration reference box
                if let maxCal = maxCalibrationValue, let restCal = restCalibrationValue {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Max(degrees): \(maxCal)")
                            .font(.rrCaption)
                            .foregroundStyle(.secondary)
                        Text("Rest(degrees): \(restCal)")
                            .font(.rrCaption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                Spacer()
                
                // Right: Live sensor data box (always visible when values are available)
                if let degrees = currentDegrees {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Current Knee Bend Angle")
                            .font(.rrCaption)
                            .foregroundStyle(.secondary)
                        Text("\(degrees)")
                            .font(.rrBody)
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            
            // Pause/Resume and Restart buttons (only when lesson has started)
            if hasStarted {
                HStack(spacing: 12) {
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
                .padding(.bottom, 8)
            }
            
            // Controls row (secondary begin button)
            HStack {
                SecondaryButton(
                    title: hasStarted ? "Lesson Running…" : "Begin Lesson",
                    isDisabled: hasStarted
                ) {
                    guard !hasStarted else { return }
                    hasStarted = true
                    elapsedBaseSeconds = 0
                    elapsedReferenceTime = Date()
                    startElapsedTimer()
                    // Zero IMU value when lesson begins
                    ble.zeroIMUValue()
                    engine.reset()
                    setupRepCountingCallback()
                    startSensorValidation()
                    // Start countdown immediately (initial countdown)
                    startCountdown(isInitial: true)
                    // Sync "started" (0 reps) so PT sees progress immediately
                    if let lessonId = lessonId {
                        LocalLessonProgressStore.shared.saveDraft(lessonId: lessonId, repsCompleted: 0, repsTarget: engine.repTarget, elapsedSeconds: 0, status: "inProgress")
                        enqueueAndSyncLessonProgress(lessonId: lessonId, repsCompleted: 0, repsTarget: engine.repTarget, elapsedSeconds: 0, status: "inProgress")
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            
            // Bottom primary action
            PrimaryButton(
                title: "Complete Session!",
                isDisabled: engine.repCount < engine.repTarget,
                useLargeFont: true
            ) {
                engine.stopGuidedSimulation()
                persistAndCompleteLesson()
                router.go(.assessment)
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
                                .fill(Color.white)
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
            persistLessonDraft()
            // Sync to Supabase on every rep so PT sees progress in real time
            if newCount > 0, let lessonId = lessonId {
                let status = newCount >= engine.repTarget ? "completed" : "inProgress"
                enqueueAndSyncLessonProgress(lessonId: lessonId, repsCompleted: newCount, repsTarget: engine.repTarget, elapsedSeconds: currentElapsedSeconds(), status: status)
            }
        }
        .onChange(of: ble.currentFlexSensorValue) { oldValue, newValue in
            if let value = newValue {
                let degrees = convertToDegrees(value)
                currentDegreeValue = degrees
            }
        }
        .onChange(of: engine.phase) { oldPhase, newPhase in
            // Reset validation flags at start of new upstroke
            if newPhase == .upstroke && oldPhase != .upstroke {
                lastRepWasValid = false
                hasSpeedError = false
            }
        }
        .onChange(of: engine.fill) { oldValue, newValue in
            // Check when box reaches full for max validation
            if newValue >= 0.99 && oldValue < 0.99 && engine.phase == .upstroke {
                if let currentDegrees = currentDegreeValue, let maxDegrees = maxCalibrationValue {
                    validateMaxReached(currentDegrees: currentDegrees, maxDegrees: maxDegrees)
                }
            }
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
    }

    private func resumeLesson() {
        guard isUserPaused else { return }
        isUserPaused = false
        elapsedReferenceTime = Date()
        startElapsedTimer()
        startSensorValidation()
        startCountdown(isInitial: false)
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
        if let lessonId = lessonId {
            LocalLessonProgressStore.shared.clearDraft(lessonId: lessonId)
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
        guard engine.repCount < engine.repTarget else {
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
                    showError("Slow down your movement!", duration: 4.0)
                    hasSpeedError = true
                }
            } else if currentDegrees < expectedDegrees - Int(toleranceRange) {
                // Behind schedule - moving too slow
                if actualRate < expectedRate * 0.5 {
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
            showError("Extend your leg further!", duration: 4.0)
            lastRepWasValid = false
        } else {
            lastRepWasValid = true
        }
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
