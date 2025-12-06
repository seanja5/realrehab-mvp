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
    let reps: Int?
    let restSec: Int?
    
    @StateObject private var engine: LessonEngine
    @StateObject private var ble = BluetoothManager.shared
    @State private var hasStarted = false
    
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
    
    // Calibration constants for degree conversion (same as CalibrateDeviceView)
    private let minSensorValue: Int = 205  // 90 degrees (rest position)
    private let sensorRange: Int = 128  // 333 - 205 = 128
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
    
    init(reps: Int? = nil, restSec: Int? = nil) {
        self.reps = reps
        self.restSec = restSec
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
        // Show error message if present
        if let error = errorMessage {
            return error
        }
        
        // Show countdown message
        if isCountingDown {
            return "Starting from rest, begin next rep in \(countdownValue)"
        }
        
        // Normal phase-based messages
        switch engine.phase {
        case .idle:
            return "Waiting…"
        case .incorrectHold:
            return "Not Quite!"
        case .upstroke, .downstroke:
            // Show "Go!" message for first 5 seconds after animation starts
            if showGoMessage, let startTime = goMessageStartTime {
                let elapsed = Date().timeIntervalSince(startTime)
                if elapsed < 5.0 {
                    return "Go!"
                }
            }
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
                
                Text("Repetitions: \(engine.repCount)/\(engine.repTarget)")
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
                    .fill(backgroundColor())
                
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
            
            // Instructions text below the feedback square
            Text(hasStarted 
                 ? "Extend your knee as the bar fills; rest as it empties.\n\nTop = full extension. Bottom = resting position."
                 : "Brace on → Press Begin.\n\nExtend your knee as the bar fills; rest as it empties.\n\nTop = full extension. Bottom = resting position.")
                .font(.rrBody)
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.top, 16)
            
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
            
            // Controls row (secondary begin button)
            HStack {
                SecondaryButton(
                    title: hasStarted ? "Lesson Running…" : "Begin Lesson",
                    isDisabled: hasStarted
                ) {
                    guard !hasStarted else { return }
                    hasStarted = true
                    engine.reset()
                    setupRepCountingCallback()
                    startSensorValidation()
                    // Start countdown immediately (initial countdown)
                    startCountdown(isInitial: true)
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
            ToolbarItem(placement: .topBarTrailing) {
                BluetoothStatusIndicator()
            }
        }
        .onAppear {
            loadCalibrationData()
        }
        .onDisappear {
            engine.stopGuidedSimulation()
            stopSensorValidation()
            countdownTimer?.invalidate()
            countdownTimer = nil
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
        // Check if error display time has expired
        if let errorEnd = errorEndTime, Date() >= errorEnd {
            clearError()
        }
        
        // Only validate if lesson is running and not paused
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
        guard errorMessage == nil else { return } // Don't override existing error
        
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
                    
                    // Use different start method based on whether this is initial or after error
                    if self.isInitialCountdown {
                        self.engine.startGuidedSimulation(skipInitialWait: true)
                    } else {
                        self.engine.restartFromBottom()
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
