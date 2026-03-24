import SwiftUI
import CoreBluetooth

private let testMode = false

/// Benchmark 2: Straight Leg Raise Control
/// Per-rep flow: Extend leg (fill box) → Lock confirm (0.4s) → Raise (hold straight 1.5s) → Rest (restSec countdown) → repeat
struct BenchmarkSLRLessonView: View {
    let reps: Int
    let restSec: Int
    let lessonId: UUID
    let lessonTitle: String

    @EnvironmentObject var router: Router
    @StateObject private var ble = BluetoothManager.shared

    // Calibration
    @State private var maxCalibrationValue: Int? = nil
    @State private var restCalibrationValue: Int? = nil
    @State private var calibrationError: String? = nil

    // Rep state
    @State private var completedReps: Int = 0
    @State private var hasStarted: Bool = false

    // Sensor fill
    @State private var fill: Double = 0.0

    // IMU warning (soft — no full restart for B2)
    @State private var hasIMUWarning: Bool = false

    // Sub-phase state machine
    private enum SLRSubPhase {
        case prepare
        case extend           // Fill box until leg is straight
        case lockConfirm      // Brief animation: box collapses to locked band
        case raise            // Hold straight while raising — arc progress fills
        case rest             // Countdown rest between reps
        case completed
    }
    @State private var subPhase: SLRSubPhase = .prepare

    // Raise phase: arc progress (0 → 1 over 1.5s)
    @State private var raiseArcProgress: Double = 0.0
    @State private var raiseStartTime: Date? = nil
    private let raiseDuration: Double = 1.5

    // Rest countdown
    @State private var restSecondsRemaining: Int = 0
    @State private var restRingProgress: Double = 1.0

    // Timers
    @State private var sensorTimer: Timer? = nil
    @State private var restTimer: Timer? = nil
    @State private var lockConfirmTimer: Timer? = nil

    // Test mode: simulated fill value
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

    private var sensorFill: Double {
        if testMode { return testSimFill }
        guard let deg = ble.currentFlexSensorValue.map({ convertToDegrees($0) }),
              let rest = restCalibrationValue,
              let max = maxCalibrationValue,
              max > rest else { return 0 }
        return Swift.max(0, Swift.min(1, (deg - Double(rest)) / Double(max - rest)))
    }

    // Dot for raise phase (same as B1 circle dot)
    private let circleSize: CGFloat = 160
    private var dotX: CGFloat {
        guard let imu = ble.currentIMUValue else { return 0 }
        return Swift.max(-1, Swift.min(1, CGFloat(imu) / 14.0)) * (circleSize / 2 * 0.55)
    }
    private var dotY: CGFloat {
        let dev = fill - 1.0
        return Swift.max(-1, Swift.min(1, CGFloat(dev) * 3.0)) * (circleSize / 2 * 0.4)
    }
    private var dotInBounds: Bool {
        let limit = circleSize / 2 * 0.6
        return abs(dotX) <= limit && abs(dotY) <= limit
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Rep progress dots strip
                if hasStarted {
                    repDotsView
                        .padding(.top, 16)
                        .padding(.horizontal, 20)
                }

                Spacer()

                VStack(spacing: 24) {
                    switch subPhase {
                    case .prepare:
                        prepareView

                    case .extend:
                        extendView(geo: geo)

                    case .lockConfirm:
                        lockConfirmView

                    case .raise:
                        raiseView

                    case .rest:
                        restView

                    case .completed:
                        completedView
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .rrPageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(lessonTitle)
        .navigationBarBackButtonHidden(true)
        .toolbar { ToolbarItem(placement: .topBarLeading) { BackButton() } }
        .onAppear { loadCalibration() }
        .onDisappear {
            stopAll()
            ble.resetIMUZero()
        }
        .onChange(of: ble.currentFlexSensorValue) { _, _ in
            updateSensorState()
        }
        .onChange(of: ble.currentIMUValue) { _, newVal in
            guard let val = newVal else { return }
            hasIMUWarning = abs(val) > 7.0
        }
    }

    // MARK: - Subviews

    private var repDotsView: some View {
        HStack(spacing: 10) {
            ForEach(0..<reps, id: \.self) { i in
                ZStack {
                    Circle()
                        .fill(i < completedReps ? Color(red: 0.2, green: 0.85, blue: 0.35) : Color.gray.opacity(0.2))
                        .frame(width: 18, height: 18)
                    if i == completedReps && subPhase != .completed {
                        Circle()
                            .stroke(Color.brandDarkBlue, lineWidth: 2)
                            .frame(width: 22, height: 22)
                            .scaleEffect(1.0)
                            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: subPhase == .raise)
                    }
                }
            }
        }
    }

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
                Text("Straight Leg Raise")
                    .font(.rrHeadline)

                Text("First straighten your leg, then raise it while keeping your knee straight. Complete \(reps) raises.")
                    .font(.rrBody)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                PrimaryButton(title: "Begin Benchmark", useLargeFont: true) {
                    startBenchmark()
                }
            }
        }
    }

    private func extendView(geo: GeometryProxy) -> some View {
        let boxH: CGFloat = geo.size.height * 0.48
        let boxW: CGFloat = geo.size.width - 40

        return VStack(spacing: 20) {
            Text(hasIMUWarning ? "Stabilize your hip!" : "Straighten your leg fully")
                .font(.rrTitle)
                .foregroundStyle(hasIMUWarning ? Color.orange : Color.primary)
                .animation(.easeInOut(duration: 0.2), value: hasIMUWarning)

            Text("Rep \(completedReps + 1) of \(reps)")
                .font(.rrBody)
                .foregroundStyle(.secondary)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.gray.opacity(0.12))
                    .frame(width: boxW, height: boxH)

                RoundedRectangle(cornerRadius: 14)
                    .fill(
                        LinearGradient(
                            colors: hasIMUWarning
                                ? [Color.orange.opacity(0.3), Color.orange.opacity(0.5)]
                                : [Color(red: 0.10, green: 0.80, blue: 0.15).opacity(0.38), Color(red: 0.04, green: 0.50, blue: 0.08).opacity(0.60)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: boxW, height: boxH * max(0.06, fill))
                    .animation(.linear(duration: 0.08), value: fill)

                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.brandDarkBlue.opacity(0.18), lineWidth: 1.5)
                    .frame(width: boxW, height: boxH)
            }

            Text("Fill the bar completely")
                .font(.rrCaption)
                .foregroundStyle(.secondary)
        }
    }

    private var lockConfirmView: some View {
        VStack(spacing: 24) {
            // Compressed "locked" band with checkmark
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.04, green: 0.50, blue: 0.08).opacity(0.25))
                    .frame(height: 56)

                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.35))
                    Text("Knee locked straight!")
                        .font(.rrTitle)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 20)
            .transition(.scale(scale: 1.0, anchor: .top).combined(with: .opacity))

            Text("Now raise your leg!")
                .font(.rrHeadline)
                .foregroundStyle(Color.brandDarkBlue)
                .transition(.opacity)
        }
    }

    private var raiseView: some View {
        VStack(spacing: 20) {
            Text(hasIMUWarning ? "Stabilize your hip!" : "Raise your leg — keep it straight!")
                .font(.rrTitle)
                .foregroundStyle(hasIMUWarning ? Color.orange : Color.primary)
                .multilineTextAlignment(.center)
                .animation(.easeInOut(duration: 0.2), value: hasIMUWarning)

            ZStack {
                // Outer arc ring
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 5)
                    .frame(width: circleSize + 16, height: circleSize + 16)

                Circle()
                    .trim(from: 0, to: raiseArcProgress)
                    .stroke(Color(red: 0.2, green: 0.85, blue: 0.35), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: circleSize + 16, height: circleSize + 16)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.08), value: raiseArcProgress)

                // Inner circle
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: circleSize, height: circleSize)
                    .overlay(Circle().stroke(Color.brandDarkBlue.opacity(0.2), lineWidth: 1.5))

                // Position dot
                Circle()
                    .fill(dotInBounds ? Color(red: 0.2, green: 0.85, blue: 0.35) : Color.orange)
                    .frame(width: 22, height: 22)
                    .shadow(color: (dotInBounds ? Color.green : Color.orange).opacity(0.4), radius: 4)
                    .offset(x: dotX, y: dotY)
                    .animation(.linear(duration: 0.05), value: dotX)
                    .animation(.linear(duration: 0.05), value: dotY)
            }

            Text(dotInBounds ? "Knee straight — hold it!" : "Keep knee straight!")
                .font(.rrBody)
                .foregroundStyle(dotInBounds ? Color.secondary : Color.orange)
                .animation(.easeInOut(duration: 0.2), value: dotInBounds)
        }
    }

    private var restView: some View {
        VStack(spacing: 20) {
            Text("Rep \(completedReps) of \(reps) done!")
                .font(.rrTitle)
                .foregroundStyle(Color(red: 0.2, green: 0.85, blue: 0.35))

            Text("Rest")
                .font(.rrHeadline)
                .foregroundStyle(.primary)

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 6)
                    .frame(width: 160, height: 160)

                Circle()
                    .trim(from: 0, to: restRingProgress)
                    .stroke(Color.brandDarkBlue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: restRingProgress)

                Text("\(restSecondsRemaining)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.brandDarkBlue)
                    .contentTransition(.numericText())
                    .animation(.spring, value: restSecondsRemaining)
            }

            Text("Next rep in \(restSecondsRemaining)s")
                .font(.rrBody)
                .foregroundStyle(.secondary)
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

            Text("All \(reps) raises completed.")
                .font(.rrBody)
                .foregroundStyle(.secondary)

            PrimaryButton(title: "Continue", useLargeFont: true) {
                router.go(.assessment(lessonId: lessonId))
            }
        }
    }

    // MARK: - Logic

    private func startBenchmark() {
        hasStarted = true
        if !testMode { ble.zeroIMUValue() }
        completedReps = 0
        subPhase = .extend
        startSensorTimer()
        if testMode { startTestSimulation() }
    }

    private func updateSensorState() {
        let newFill = sensorFill
        withAnimation(.linear(duration: 0.08)) { fill = newFill }

        switch subPhase {
        case .extend:
            if fill >= 0.92 {
                beginLockConfirm()
            }
        case .raise:
            updateRaiseArc()
        default:
            break
        }
    }

    private func beginLockConfirm() {
        guard subPhase == .extend else { return }
        subPhase = .lockConfirm
        lockConfirmTimer?.invalidate()
        lockConfirmTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { _ in
            self.subPhase = .raise
            self.raiseArcProgress = 0.0
            self.raiseStartTime = Date()
        }
    }

    private func updateRaiseArc() {
        guard subPhase == .raise, let start = raiseStartTime else { return }
        // Arc fills only while leg is straight and IMU in bounds
        if fill >= 0.80 && dotInBounds {
            let elapsed = Date().timeIntervalSince(start)
            let newProgress = Swift.min(1.0, elapsed / raiseDuration)
            raiseArcProgress = newProgress
            if newProgress >= 1.0 {
                countRep()
            }
        } else {
            // Reset arc if they lose straight
            raiseStartTime = Date()
            withAnimation(.linear(duration: 0.1)) { raiseArcProgress = 0.0 }
        }
    }

    private func countRep() {
        guard subPhase == .raise else { return }
        completedReps += 1
        if completedReps >= reps {
            finishBenchmark()
        } else {
            startRest()
        }
    }

    private func startRest() {
        subPhase = .rest
        restSecondsRemaining = restSec
        restRingProgress = 1.0
        let totalDuration = Double(restSec)
        let startTime = Date()

        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            let elapsed = Date().timeIntervalSince(startTime)
            let remaining = max(0, totalDuration - elapsed)
            self.restSecondsRemaining = Int(ceil(remaining))
            self.restRingProgress = remaining / totalDuration
            if remaining <= 0 {
                self.restTimer?.invalidate()
                self.restTimer = nil
                self.fill = 0
                self.testSimFill = 0
                self.raiseArcProgress = 0.0
                self.raiseStartTime = nil
                self.subPhase = .extend
                if testMode { self.startTestSimulation() }
            }
        }
    }

    private func finishBenchmark() {
        subPhase = .completed
        stopAll()
        persistProgress()
    }

    private func persistProgress() {
        LocalLessonProgressStore.shared.saveDraft(
            lessonId: lessonId, repsCompleted: reps, repsTarget: reps,
            elapsedSeconds: reps * (restSec + 3), status: "completed"
        )
        Task {
            guard let profile = try? await AuthService.myProfile(),
                  let patientProfileId = try? await PatientService.myPatientProfileId(profileId: profile.id) else { return }
            OutboxSyncManager.shared.enqueueLessonProgress(
                patientProfileId: patientProfileId, lessonId: lessonId,
                repsCompleted: reps, repsTarget: reps,
                elapsedSeconds: reps * (restSec + 3), status: "completed"
            )
            await OutboxSyncManager.shared.processQueueIfOnline()
            await CacheService.shared.invalidate(CacheKey.lessonProgress(patientProfileId: patientProfileId))
            await CacheService.shared.invalidate(CacheKey.completionDates(patientProfileId: patientProfileId))
        }
    }

    private func startSensorTimer() {
        sensorTimer?.invalidate()
        sensorTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.updateSensorState()
        }
    }

    private func stopAll() {
        sensorTimer?.invalidate(); sensorTimer = nil
        restTimer?.invalidate(); restTimer = nil
        lockConfirmTimer?.invalidate(); lockConfirmTimer = nil
        testSimTimer?.invalidate(); testSimTimer = nil
    }

    /// Test mode: ramp fill 0 → 1 over 2.5s to simulate the patient extending their leg for each rep.
    private func startTestSimulation() {
        testSimTimer?.invalidate()
        testSimFill = 0
        let start = Date()
        let rampDuration: Double = 2.5
        testSimTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [self] _ in
            let elapsed = Date().timeIntervalSince(start)
            let newFill = Swift.min(1.0, elapsed / rampDuration)
            testSimFill = newFill
            updateSensorState()
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
