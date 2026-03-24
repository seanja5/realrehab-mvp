import SwiftUI
import Combine
import CoreBluetooth

private let testMode = false

struct BenchmarkExtensionLessonView: View {
    let holdDuration: Int
    let lessonId: UUID
    let lessonTitle: String

    @EnvironmentObject var router: Router
    @StateObject private var ble = BluetoothManager.shared

    // Calibration
    @State private var maxCalibrationValue: Int? = nil
    @State private var restCalibrationValue: Int? = nil
    @State private var calibrationError: String? = nil

    // Sensor-driven fill (0.0 – 1.0)
    @State private var fill: Double = 0.0

    // IMU
    @State private var hasIMUError: Bool = false

    // State machine
    private enum BenchmarkPhase { case prepare, filling, transitioning, holding, holdFailed, completed }
    @State private var phase: BenchmarkPhase = .prepare

    // Animation geometry: corner radius interpolates box → circle
    @State private var shapeCornerRadius: CGFloat = 14
    @State private var shapeWidth: CGFloat = 0      // set from geometry
    @State private var shapeHeight: CGFloat = 0
    @State private var geoSize: CGSize = .zero
    @State private var hasStarted: Bool = false

    private var circleSize: CGFloat {
        guard geoSize.width > 0 else { return 300 }
        return geoSize.width - 60   // fills most of screen, ~330pt on a 390pt phone
    }

    // Hold countdown
    @State private var holdSecondsRemaining: Int = 0
    @State private var ringProgress: Double = 1.0    // 1.0 = full ring, 0.0 = empty
    @State private var holdTimer: Timer? = nil
    @State private var failDwellTimer: Timer? = nil   // detects sustained out-of-bounds
    @State private var outOfBoundsStart: Date? = nil

    // Restart countdown after failure
    @State private var restartCountdown: Int = 3
    @State private var restartTimer: Timer? = nil

    // Sensor validation timer
    @State private var sensorTimer: Timer? = nil

    // Test mode: simulated fill value driven by timer
    @State private var testSimFill: Double = 0.0
    @State private var testSimTimer: Timer? = nil

    // Calibration constants
    private let minSensorValue: Int = 185
    private let sensorRange: Int = 115
    private let minDegrees: Double = 90.0
    private let degreeRange: Double = 90.0

    private func convertToDegrees(_ v: Int) -> Double {
        minDegrees + (Double(v - minSensorValue) / Double(sensorRange)) * degreeRange
    }

    private var currentDegrees: Double? {
        guard let v = ble.currentFlexSensorValue else { return nil }
        return convertToDegrees(v)
    }

    /// Normalized fill: 0 = at rest calibration, 1 = at max calibration
    private var sensorFill: Double {
        if testMode { return testSimFill }
        guard let deg = currentDegrees,
              let rest = restCalibrationValue,
              let max = maxCalibrationValue,
              max > rest else { return 0 }
        let f = (deg - Double(rest)) / Double(max - rest)
        return Swift.max(0, Swift.min(1, f))
    }

    // Dot position inside hold circle
    private var dotX: CGFloat {
        guard let imu = ble.currentIMUValue else { return 0 }
        let frac = CGFloat(imu) / 14.0         // ±7 maps to ±0.5
        return Swift.max(-1, Swift.min(1, frac)) * (circleSize / 2 * 0.55)
    }
    private var dotY: CGFloat {
        let dev = fill - 1.0                   // small deviation from max (negative = below max)
        return Swift.max(-1, Swift.min(1, CGFloat(dev) * 3.0) ) * (circleSize / 2 * 0.4)
    }

    private var dotOutOfBounds: Bool {
        let limit: CGFloat = circleSize / 2 * 0.55
        return abs(dotX) > limit * 0.7 || abs(dotY) > limit * 0.7
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                VStack(spacing: 0) {
                    Spacer()

                    switch phase {
                    case .prepare:
                        prepareView

                    case .filling, .transitioning:
                        fillingView

                    case .holding:
                        holdingView

                    case .holdFailed:
                        holdFailedView

                    case .completed:
                        completedView
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
            }
            .onAppear { geoSize = geo.size }
        }
        .rrPageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(lessonTitle)
        .navigationBarBackButtonHidden(true)
        .toolbar { ToolbarItem(placement: .topBarLeading) { BackButton() } }
        .onAppear {
            loadCalibration()
        }
        .onDisappear {
            stopAll()
            ble.resetIMUZero()
        }
        .onChange(of: ble.currentFlexSensorValue) { _, _ in
            if phase == .filling || phase == .transitioning {
                updateFill()
            } else if phase == .holding {
                updateFill()
                checkHoldBounds()
            }
        }
        .onChange(of: ble.currentIMUValue) { _, newVal in
            guard let val = newVal else { return }
            let newError = abs(val) > 7.0
            if newError != hasIMUError {
                hasIMUError = newError
            }
            if phase == .filling && newError {
                triggerIMURestart()
            }
        }
    }

    // MARK: - Subviews

    private var prepareView: some View {
        VStack(spacing: 28) {
            if let err = calibrationError {
                Text(err)
                    .font(.rrBody)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            } else if restCalibrationValue == nil || maxCalibrationValue == nil {
                ProgressView()
                Text("Loading calibration...")
                    .font(.rrBody)
                    .foregroundStyle(.secondary)
            } else {
                Text("Straighten your leg fully and hold it steady.")
                    .font(.rrTitle)
                    .multilineTextAlignment(.center)

                Text("Fill the bar by extending your leg, then hold when prompted.")
                    .font(.rrBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                PrimaryButton(title: "Begin Benchmark", useLargeFont: true) {
                    startBenchmark()
                }
            }
        }
    }

    private var fillingView: some View {
        VStack(spacing: 24) {
            Text(phase == .transitioning ? "Hold it there!" : (hasIMUError ? "Keep your hip steady!" : "Extend your leg"))
                .font(.rrTitle)
                .foregroundStyle(hasIMUError ? Color.red : Color.primary)
                .animation(.easeInOut(duration: 0.2), value: hasIMUError)

            // Main animated box — shapeWidth/shapeHeight animate from box to circle
            ZStack(alignment: .bottom) {
                // Background
                RoundedRectangle(cornerRadius: shapeCornerRadius)
                    .fill(Color.gray.opacity(0.12))
                    .frame(width: shapeWidth, height: shapeHeight)

                // Fill overlay
                RoundedRectangle(cornerRadius: shapeCornerRadius)
                    .fill(
                        LinearGradient(
                            colors: hasIMUError
                                ? [Color(red: 1.0, green: 0.25, blue: 0.25).opacity(0.35), Color(red: 0.75, green: 0.08, blue: 0.08).opacity(0.55)]
                                : [Color(red: 0.10, green: 0.80, blue: 0.15).opacity(0.38), Color(red: 0.04, green: 0.50, blue: 0.08).opacity(0.60)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: shapeWidth, height: shapeHeight * max(0.06, fill))
                    .animation(.linear(duration: 0.08), value: fill)

                // Rim border
                RoundedRectangle(cornerRadius: shapeCornerRadius)
                    .stroke(hasIMUError ? Color.red.opacity(0.4) : Color.brandDarkBlue.opacity(0.18), lineWidth: 1.5)
                    .frame(width: shapeWidth, height: shapeHeight)

                // User position line + IMU dot — hide during transition
                if phase == .filling, let _ = restCalibrationValue, let _ = maxCalibrationValue {
                    let userPos = CGFloat(fill)
                    let imuPos: CGFloat = {
                        guard let imu = ble.currentIMUValue else { return 0.5 }
                        return CGFloat(0.5 - Double(imu) / 14.0)
                    }()

                    Rectangle()
                        .fill(Color.brandDarkBlue.opacity(0.7))
                        .frame(width: shapeWidth, height: 2)
                        .offset(y: -shapeHeight * userPos + shapeHeight / 2)
                        .clipShape(RoundedRectangle(cornerRadius: shapeCornerRadius))
                        .allowsHitTesting(false)

                    Circle()
                        .fill(Color.brandDarkBlue)
                        .frame(width: 14, height: 14)
                        .offset(
                            x: (imuPos - 0.5) * shapeWidth * 0.8,
                            y: -shapeHeight * userPos + shapeHeight / 2
                        )
                        .allowsHitTesting(false)
                }
            }

            if phase == .filling {
                Text("Fill the bar all the way")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var holdingView: some View {
        VStack(spacing: 20) {
            Text("\(holdSecondsRemaining)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(Color.brandDarkBlue)
                .contentTransition(.numericText())
                .animation(.spring, value: holdSecondsRemaining)

            Text("Hold steady")
                .font(.rrTitle)
                .foregroundStyle(.primary)

            ZStack {
                // Outer countdown ring
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 6)
                    .frame(width: circleSize + 16, height: circleSize + 16)

                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(Color.brandDarkBlue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: circleSize + 16, height: circleSize + 16)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: ringProgress)

                // Inner hold circle
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: circleSize, height: circleSize)
                    .overlay(
                        Circle()
                            .stroke(Color.brandDarkBlue.opacity(0.2), lineWidth: 1.5)
                    )

                // Position dot
                Circle()
                    .fill(dotOutOfBounds ? Color.red : Color(red: 0.10, green: 0.80, blue: 0.15))
                    .frame(width: 28, height: 28)
                    .shadow(color: (dotOutOfBounds ? Color.red : Color.green).opacity(0.5), radius: 6)
                    .offset(x: dotX, y: dotY)
                    .animation(.linear(duration: 0.05), value: dotX)
                    .animation(.linear(duration: 0.05), value: dotY)
            }
            .frame(maxWidth: .infinity)

            Text(dotOutOfBounds ? "Keep the dot centered!" : "Keep the dot in the circle")
                .font(.rrBody)
                .foregroundStyle(dotOutOfBounds ? Color.red : Color.secondary)
                .animation(.easeInOut(duration: 0.2), value: dotOutOfBounds)
        }
        .frame(maxWidth: .infinity)
    }

    private var holdFailedView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 140, height: 140)
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(Color.red.opacity(0.8))
            }

            Text("Hold lost")
                .font(.rrHeadline)
                .foregroundStyle(.primary)

            Text("Restarting in \(restartCountdown)...")
                .font(.rrTitle)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(.spring, value: restartCountdown)
        }
    }

    private var completedView: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.2, green: 0.85, blue: 0.35).opacity(0.15))
                    .frame(width: 140, height: 140)
                Image(systemName: "checkmark")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.35))
            }

            Text("Benchmark Complete!")
                .font(.rrHeadline)
                .foregroundStyle(.primary)

            PrimaryButton(title: "Continue", useLargeFont: true) {
                router.go(.assessment(lessonId: lessonId))
            }
        }
    }

    // MARK: - Logic

    private func startBenchmark() {
        hasStarted = true
        if !testMode { ble.zeroIMUValue() }
        // Initialize box to full available area
        shapeWidth = geoSize.width - 40
        shapeHeight = geoSize.height * 0.55
        shapeCornerRadius = 14
        phase = .filling
        startSensorTimer()
        if testMode { startTestSimulation() }
    }

    private func updateFill() {
        let newFill = sensorFill
        withAnimation(.linear(duration: 0.08)) {
            fill = newFill
        }
        // Trigger transition when near max
        if phase == .filling && fill >= 0.92 {
            transitionToHold()
        }
    }

    private func transitionToHold() {
        guard phase == .filling else { return }
        phase = .transitioning
        let target = circleSize
        withAnimation(.easeInOut(duration: 0.65)) {
            shapeWidth = target
            shapeHeight = target
            shapeCornerRadius = target / 2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            guard self.phase == .transitioning else { return }
            self.startHold()
        }
    }

    private func startHold() {
        phase = .holding
        holdSecondsRemaining = holdDuration
        ringProgress = 1.0
        outOfBoundsStart = nil

        let totalDuration = Double(holdDuration)
        let startTime = Date()

        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] _ in
            let elapsed = Date().timeIntervalSince(startTime)
            let remaining = max(0, totalDuration - elapsed)
            holdSecondsRemaining = Int(ceil(remaining))
            ringProgress = remaining / totalDuration

            if remaining <= 0 {
                holdTimer?.invalidate()
                holdTimer = nil
                completeBenchmark()
            }
        }
    }

    private func checkHoldBounds() {
        guard phase == .holding else { return }
        if dotOutOfBounds {
            if outOfBoundsStart == nil {
                outOfBoundsStart = Date()
            } else if let start = outOfBoundsStart, Date().timeIntervalSince(start) > 0.4 {
                triggerHoldFailed()
            }
        } else {
            outOfBoundsStart = nil
        }
    }

    private func triggerIMURestart() {
        guard phase == .filling else { return }
        // Only restart if we've been out of bounds for >0.5s (avoid false triggers)
        // For filling phase, IMU error just turns box red and resets after countdown
        phase = .holdFailed
        holdTimer?.invalidate()
        holdTimer = nil
        fill = 0
        startRestartCountdown()
    }

    private func triggerHoldFailed() {
        guard phase == .holding else { return }
        holdTimer?.invalidate()
        holdTimer = nil
        phase = .holdFailed
        fill = 0
        startRestartCountdown()
    }

    private func startRestartCountdown() {
        restartCountdown = 3
        restartTimer?.invalidate()
        restartTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if self.restartCountdown > 1 {
                self.restartCountdown -= 1
            } else {
                self.restartTimer?.invalidate()
                self.restartTimer = nil
                self.resetToFilling()
            }
        }
    }

    private func resetToFilling() {
        fill = 0
        testSimFill = 0
        outOfBoundsStart = nil
        shapeWidth = geoSize.width - 40
        shapeHeight = geoSize.height * 0.55
        shapeCornerRadius = 14
        phase = .filling
        if testMode { startTestSimulation() }
    }

    private func completeBenchmark() {
        phase = .completed
        stopAll()
        persistProgress()
    }

    private func persistProgress() {
        LocalLessonProgressStore.shared.saveDraft(
            lessonId: lessonId, repsCompleted: 1, repsTarget: 1,
            elapsedSeconds: holdDuration, status: "completed"
        )
        Task {
            guard let profile = try? await AuthService.myProfile(),
                  let patientProfileId = try? await PatientService.myPatientProfileId(profileId: profile.id) else { return }
            OutboxSyncManager.shared.enqueueLessonProgress(
                patientProfileId: patientProfileId, lessonId: lessonId,
                repsCompleted: 1, repsTarget: 1, elapsedSeconds: holdDuration, status: "completed"
            )
            await OutboxSyncManager.shared.processQueueIfOnline()
            await CacheService.shared.invalidate(CacheKey.lessonProgress(patientProfileId: patientProfileId))
            await CacheService.shared.invalidate(CacheKey.completionDates(patientProfileId: patientProfileId))
        }
    }

    private func startSensorTimer() {
        sensorTimer?.invalidate()
        sensorTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if self.phase == .filling || self.phase == .holding {
                self.updateFill()
                if self.phase == .holding { self.checkHoldBounds() }
            }
        }
    }

    private func stopAll() {
        holdTimer?.invalidate(); holdTimer = nil
        restartTimer?.invalidate(); restartTimer = nil
        sensorTimer?.invalidate(); sensorTimer = nil
        failDwellTimer?.invalidate(); failDwellTimer = nil
        testSimTimer?.invalidate(); testSimTimer = nil
    }

    /// Test mode: ramp fill from 0 → 1 over 3 seconds, simulating the patient extending their leg.
    private func startTestSimulation() {
        testSimTimer?.invalidate()
        testSimFill = 0
        let start = Date()
        let rampDuration: Double = 3.0
        testSimTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [self] _ in
            let elapsed = Date().timeIntervalSince(start)
            let newFill = Swift.min(1.0, elapsed / rampDuration)
            testSimFill = newFill
            updateFill()
            if newFill >= 1.0 {
                testSimTimer?.invalidate()
                testSimTimer = nil
            }
        }
    }

    private func loadCalibration() {
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
        Task {
            do {
                let cal = try await TelemetryService.getMostRecentCalibration(bluetoothIdentifier: bluetoothIdentifier)
                await MainActor.run {
                    maxCalibrationValue = cal.maxDegrees
                    restCalibrationValue = cal.restDegrees
                    if cal.maxDegrees == nil || cal.restDegrees == nil {
                        calibrationError = "No calibration data found. Please calibrate your device first."
                    }
                }
            } catch {
                await MainActor.run {
                    calibrationError = "Failed to load calibration: \(error.localizedDescription)"
                }
            }
        }
    }
}

