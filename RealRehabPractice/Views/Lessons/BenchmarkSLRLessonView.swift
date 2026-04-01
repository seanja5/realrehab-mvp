import SwiftUI
import CoreBluetooth

private let testMode = true

/// Benchmark 2: Straight Leg Raise — extend with flex → 10s prep countdown → guided reps (LessonEngine SLR) with IMU for line/dot.
struct BenchmarkSLRLessonView: View {
    let reps: Int
    let restSec: Int
    let lessonId: UUID
    let lessonTitle: String

    @EnvironmentObject var router: Router
    @StateObject private var ble = BluetoothManager.shared
    @StateObject private var engine: LessonEngine

    // Calibration
    @State private var maxCalibrationValue: Int? = nil
    @State private var restCalibrationValue: Int? = nil
    @State private var calibrationError: String? = nil

    @State private var hasStarted: Bool = false
    @State private var fill: Double = 0.0
    @State private var hasIMUWarning: Bool = false

    // Animation geometry (mirrors BenchmarkExtensionLessonView pattern)
    @State private var geoSize: CGSize = .zero
    @State private var innerCardH: CGFloat = 0   // measured from inside extendAndPrepView after layout settles
    @State private var animBoxH: CGFloat = 0
    @State private var extendFillOpacity: Double = 1.0

    private enum SLRPhase {
        case prepare
        case extend
        case prepCountdown
        case mainExercise
        case completed
    }

    @State private var phase: SLRPhase = .prepare

    private let prepTotalSeconds: Double = 10.0
    @State private var prepSecondsRemaining: Double = 10.0
    @State private var prepTimer: Timer? = nil
    @State private var showPrepCountdownContent: Bool = false

    @State private var sensorTimer: Timer? = nil
    @State private var testSimTimer: Timer? = nil
    @State private var testSimFill: Double = 0.0

    @State private var elapsedBaseSeconds: Int = 0
    @State private var elapsedReferenceTime: Date? = nil
    @State private var elapsedDisplaySeconds: Int = 0
    @State private var elapsedTimer: Timer? = nil

    @State private var lastRepWasValid: Bool = true

    private let minSensorValue: Int = 185
    private let sensorRange: Int = 115
    private let minDegrees: Double = 90.0
    private let degreeRange: Double = 90.0

    init(reps: Int, restSec: Int, lessonId: UUID, lessonTitle: String) {
        self.reps = reps
        self.restSec = restSec
        self.lessonId = lessonId
        self.lessonTitle = lessonTitle
        let targets = LessonTargets.defaults(for: .straightLegRaise, lessonTitle: lessonTitle)
        let eng = LessonEngine(
            repTarget: reps,
            restDuration: TimeInterval(restSec),
            exerciseType: .straightLegRaise,
            setTotal: 1,
            setRestDuration: 60
        )
        eng.targets = targets
        _engine = StateObject(wrappedValue: eng)
    }

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

    /// Vertical line position: 0 bottom, 1 top (matches LessonView semantics).
    private func verticalLineNormalized() -> CGFloat? {
        if testMode, phase == .mainExercise {
            return CGFloat(engine.fill)
        }
        guard let v = ble.currentIMUVertical else { return 0.5 }
        let n = 0.5 + Double(v) / 14.0
        return CGFloat(Swift.max(0, Swift.min(1, n)))
    }

    /// Horizontal dot 0...1 (left...right), same as LessonView `imuCirclePosition`.
    private func imuHorizontalNormalized() -> CGFloat {
        guard let imu = ble.currentIMUValue else { return 0.5 }
        let pos = 0.5 - (Double(imu) / 14.0)
        return CGFloat(Swift.max(0, Swift.min(1, pos)))
    }

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .center, spacing: 0) {
                // Progress header — hidden on the prepare screen so the video can take that spot
                if phase == .prepare {
                    if restCalibrationValue != nil && maxCalibrationValue != nil && calibrationError == nil {
                        LoopingVideoView(videoName: "StraightLegRaise")
                            .frame(maxWidth: .infinity)
                            .frame(height: 260)
                            .clipped()
                    }
                } else {
                    progressHeader
                        .padding(.top, 4)
                }

                // Main card (same size/feel as LessonView)
                ZStack {
                    switch phase {
                    case .prepare:
                        prepareView
                    case .extend, .prepCountdown:
                        extendAndPrepView(geo: geo)
                    case .mainExercise:
                        mainExerciseCardContent(geo: geo)
                    case .completed:
                        completedView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 20)
                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
            }
            .onAppear { geoSize = geo.size }
        }
        .rrPageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(lessonTitle)
        .navigationBarBackButtonHidden(true)
        .swipeToGoBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { BackButton() }
            ToolbarItem(placement: .topBarTrailing) { BluetoothStatusIndicator() }
        }
        .onAppear { loadCalibration() }
        .onDisappear {
            stopAll()
            engine.stopGuidedSimulation()
            ble.resetIMUZero()
        }
        .onChange(of: ble.currentFlexSensorValue) { _, _ in
            updateExtendSensor()
        }
        .onChange(of: ble.currentIMUValue) { _, newVal in
            guard let val = newVal else { return }
            hasIMUWarning = abs(val) > 7.0
        }
        .onChange(of: engine.isFullyComplete) { _, done in
            if done, phase == .mainExercise { finishBenchmark() }
        }
        .onChange(of: engine.repCount) { _, newCount in
            guard phase == .mainExercise, newCount > 0 else { return }
            persistDraftProgress()
            LessonSensorInsightsCollector.shared.saveDraftIntermediate(
                repsCompleted: newCount,
                totalDurationSec: currentElapsedSeconds()
            )
            Task {
                await syncProgress(repsCompleted: newCount, status: engine.isFullyComplete ? "completed" : "inProgress")
            }
        }
        .onChange(of: engine.phase) { oldP, newP in
            if newP == .upstroke && oldP != .upstroke {
                lastRepWasValid = false
            }
        }
        .onChange(of: engine.fill) { oldF, newF in
            guard phase == .mainExercise else { return }
            if newF >= 0.99 && oldF < 0.99 && engine.phase == .upstroke {
                validatePeakIMU()
            }
        }
    }

    // MARK: - Progress header (copy LessonView style)

    private var progressHeader: some View {
        VStack(spacing: 6) {
            ProgressView(value: min(Double(engine.repCount) / Double(max(1, engine.repTarget)), 1.0))
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
    }

    // MARK: - Prepare

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
                Text("For this benchmark, lie down and extend your leg as far as you comfortably can. Once you’re there, you’ll be prompted to raise your leg up and down along with the animation. Keep your leg straight the entire time.")
                    .font(.rrHeadline)
                    .multilineTextAlignment(.center)
                PrimaryButton(title: "Begin Benchmark", useLargeFont: true) {
                    startBenchmark()
                }
            }
        }
    }

    // MARK: - Extend + PrepCountdown (single unified view for smooth transition)

    private func extendAndPrepView(geo: GeometryProxy) -> some View {
        // Full card width — matches BenchmarkExtensionLessonView's shapeWidth = geoSize.width - 40
        let targetW: CGFloat = geo.size.width - 40
        let ringProgress = CGFloat(prepSecondsRemaining / prepTotalSeconds)
        let stripH: CGFloat = max(16, animBoxH * 0.12)

        // Outer ZStack fills the card (maxHeight: .infinity). Inner box is centered at animBoxH.
        // clipShape prevents overflow. innerCardH is measured here (after layout settles),
        // not in body — avoids the pre-constraint measurement bug.
        return ZStack {
            // ── Height measurement (fires after layout is fully resolved) ─
            GeometryReader { inner in
                Color.clear.onAppear {
                    if inner.size.height > 100 { innerCardH = inner.size.height }
                }
            }

            // ── Animated box background ──────────────────────────────────
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.gray.opacity(0.12))
                .frame(width: targetW, height: animBoxH)

            // ── Green fill rises from bottom, fades on transition ────────
            VStack {
                Spacer(minLength: 0)
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.80, blue: 0.15).opacity(0.38),
                            Color(red: 0.04, green: 0.50, blue: 0.08).opacity(0.60)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    ))
                    .frame(width: targetW, height: animBoxH * max(0.06, fill))
                    .animation(.linear(duration: 0.08), value: fill)
            }
            .frame(width: targetW, height: animBoxH)
            .opacity(extendFillOpacity)

            // ── Blue tracking line + dot (extend phase only) ─────────────
            if phase == .extend {
                let userPos = CGFloat(fill)
                let imuPos: CGFloat = {
                    guard let imu = ble.currentIMUValue else { return 0.5 }
                    return CGFloat(0.5 - Double(imu) / 14.0)
                }()
                Rectangle()
                    .fill(Color.brandDarkBlue.opacity(0.7))
                    .frame(width: targetW, height: 2)
                    .offset(y: animBoxH * (0.5 - userPos))
                    .allowsHitTesting(false)
                Circle()
                    .fill(Color.brandDarkBlue)
                    .frame(width: 14, height: 14)
                    .offset(x: (imuPos - 0.5) * targetW * 0.8,
                            y: animBoxH * (0.5 - userPos))
                    .allowsHitTesting(false)
            }

            // ── Countdown content — centered, shifted up to clear strip ──
            if showPrepCountdownContent {
                VStack(spacing: 16) {
                    Text("Hold your leg in this position, and get ready to do the straight leg raises for the amount of reps shown.")
                        .font(.rrHeadline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.15), lineWidth: 6)
                            .frame(width: 132, height: 132)
                        Circle()
                            .trim(from: 0, to: ringProgress)
                            .stroke(Color.brandDarkBlue, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 132, height: 132)
                            .rotationEffect(.degrees(-90))
                        Text("\(Int(ceil(prepSecondsRemaining)))")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.brandDarkBlue)
                    }
                }
                // Offset upward by half the strip height so content stays visually centred
                // in the remaining box area above the green strip
                .offset(y: -(stripH / 2))
                .transition(.opacity)
            }

            // ── Green base strip at bottom (start-position indicator) ────
            if showPrepCountdownContent {
                VStack {
                    Spacer(minLength: 0)
                    LinearGradient(
                        colors: [
                            Color(red: 0.10, green: 0.80, blue: 0.15).opacity(0.35),
                            Color(red: 0.04, green: 0.50, blue: 0.08).opacity(0.55)
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: stripH)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .frame(width: targetW, height: animBoxH)
                .transition(.opacity)
            }

            // ── Title inside box top — extend phase ──────────────────────
            if !showPrepCountdownContent {
                VStack {
                    Text(hasIMUWarning ? "Stabilize your hip!" : "Straighten your leg fully")
                        .font(.rrHeadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(hasIMUWarning ? Color.orange : Color.primary)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    Spacer(minLength: 0)
                }
                .frame(width: targetW, height: animBoxH)
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }

            // ── Caption inside box bottom — extend phase ─────────────────
            if phase == .extend {
                VStack {
                    Spacer(minLength: 0)
                    Text("Fill the bar completely")
                        .font(.rrCaption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 16)
                }
                .frame(width: targetW, height: animBoxH)
                .transition(.opacity.animation(.easeInOut(duration: 0.2)))
            }

            // ── Stroke border ─────────────────────────────────────────────
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.brandDarkBlue.opacity(0.18), lineWidth: 1.5)
                .frame(width: targetW, height: animBoxH)
        }
        // Fill the card; clipShape guarantees the box never overflows the card bounds
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .animation(.easeInOut(duration: 0.65), value: animBoxH)
    }

    // MARK: - Main exercise (LessonEngine + IMU line)

    private func mainExerciseCardContent(geo: GeometryProxy) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(mainCardBackground())

            if !engine.isPaused && (engine.phase == .upstroke || engine.phase == .downstroke || engine.phase == .setRest || engine.isFullyComplete) {
                GeometryReader { g in
                    let h = g.size.height
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
            }

            if let linePos = verticalLineNormalized() {
                GeometryReader { g in
                    let boxHeight = g.size.height
                    let yPosition = boxHeight * (1.0 - linePos)
                    Rectangle()
                        .fill(Color.brandDarkBlue)
                        .frame(width: g.size.width * 0.9)
                        .frame(height: 3)
                        .position(x: g.size.width / 2, y: yPosition)
                    let xNorm = imuHorizontalNormalized()
                    let xPosition = g.size.width * 0.05 + (g.size.width * 0.9 * xNorm)
                    Circle()
                        .fill(Color.brandDarkBlue)
                        .frame(width: 14, height: 14)
                        .position(x: xPosition, y: yPosition)
                }
            }

            Text(mainDisplayText())
                .font(.rrHeadline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack {
                HStack(spacing: 6) {
                    Image(systemName: ACLJourneyModels.lessonIconSystemName(for: lessonTitle))
                        .font(.system(size: 11, weight: .semibold))
                    Text("LIFT")
                        .font(.rrCaption.bold())
                        .tracking(1.5)
                }
                .foregroundStyle(Color.brandDarkBlue.opacity(0.65))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.brandDarkBlue.opacity(0.07))
                .clipShape(Capsule())
                .padding(.top, 14)
                Spacer()
            }
        }
    }

    private func mainCardBackground() -> Color {
        if engine.phase == .incorrectHold {
            return Color.red.opacity(0.04)
        }
        if engine.phase == .idle {
            return Color.gray.opacity(0.12)
        }
        return Color.brandDarkBlue.opacity(0.05)
    }

    private func mainDisplayText() -> String {
        if engine.isFullyComplete { return "You're Done!" }
        switch engine.phase {
        case .idle: return "Get ready…"
        case .incorrectHold: return "Not Quite!"
        case .holding: return "Hold It! \(engine.holdSecondsRemaining)s"
        case .upstroke: return "Lift Your Leg!"
        case .downstroke: return "Lower Slowly"
        case .setRest: return "Rest"
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
        // Same starting size as BenchmarkExtensionLessonView: width = geoSize.width - 40, height = 0.55
        animBoxH = geoSize.height * 0.55
        extendFillOpacity = 1.0
        phase = .extend
        startSensorTimer()
        if testMode { startTestSimulationExtend() }
    }

    private func updateExtendSensor() {
        guard phase == .extend else { return }
        let newFill = sensorFill
        withAnimation(.linear(duration: 0.08)) { fill = newFill }
        if fill >= 0.92 {
            testSimTimer?.invalidate()
            testSimTimer = nil
            beginPrepCountdown()
        }
    }

    private func beginPrepCountdown() {
        guard phase == .extend else { return }
        sensorTimer?.invalidate()
        sensorTimer = nil
        showPrepCountdownContent = false

        // Animate box expansion + green fill fade simultaneously (same pattern as BenchmarkExtensionLessonView)
        // innerCardH is measured from inside extendAndPrepView (after layout settles), so it reflects
        // the true available height after all padding — no overflow possible.
        let targetH = innerCardH > 100 ? innerCardH : geoSize.height * 0.72
        withAnimation(.easeInOut(duration: 0.65)) {
            phase = .prepCountdown
            animBoxH = targetH
            extendFillOpacity = 0.0
        }

        // Fade in countdown content after box expansion settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            if self.phase == .prepCountdown {
                withAnimation(.easeIn(duration: 0.18)) {
                    self.showPrepCountdownContent = true
                }
            }
        }

        prepSecondsRemaining = prepTotalSeconds
        let start = Date()
        prepTimer?.invalidate()
        prepTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            let elapsed = Date().timeIntervalSince(start)
            let rem = max(0, prepTotalSeconds - elapsed)
            prepSecondsRemaining = rem
            if rem <= 0 {
                prepTimer?.invalidate()
                prepTimer = nil
                enterMainExercise()
            }
        }
        RunLoop.main.add(prepTimer!, forMode: .common)
    }

    private func enterMainExercise() {
        phase = .mainExercise
        if !testMode {
            ble.zeroIMUValue()
        }
        engine.shouldCountRepCallback = {
            if testMode { return true }
            return self.lastRepWasValid
        }
        engine.startGuidedSimulation(skipInitialWait: true)
        startElapsedTimer()
        Task { await startInsights() }
    }

    private func validatePeakIMU() {
        if testMode {
            lastRepWasValid = true
            return
        }
        guard let v = ble.currentIMUVertical else {
            lastRepWasValid = true
            return
        }
        let expected = Float((engine.fill - 0.5) * 14.0)
        lastRepWasValid = abs(v - expected) < 5.0
    }

    private func finishBenchmark() {
        guard phase != .completed else { return }
        phase = .completed
        stopAll()
        engine.stopGuidedSimulation()
        finishInsights()
        persistProgress()
    }

    private func persistDraftProgress() {
        LocalLessonProgressStore.shared.saveDraft(
            lessonId: lessonId,
            repsCompleted: engine.repCount,
            repsTarget: engine.repTarget,
            elapsedSeconds: currentElapsedSeconds(),
            status: engine.isFullyComplete ? "completed" : "inProgress"
        )
    }

    private func persistProgress() {
        LocalLessonProgressStore.shared.saveDraft(
            lessonId: lessonId,
            repsCompleted: reps,
            repsTarget: reps,
            elapsedSeconds: currentElapsedSeconds(),
            status: "completed"
        )
        LocalLessonProgressStore.shared.clearDraft(lessonId: lessonId)
        Task {
            await syncProgress(repsCompleted: reps, status: "completed")
        }
    }

    private func syncProgress(repsCompleted: Int, status: String) async {
        guard let profile = try? await AuthService.myProfile(),
              let patientProfileId = try? await PatientService.myPatientProfileId(profileId: profile.id) else { return }
        OutboxSyncManager.shared.enqueueLessonProgress(
            patientProfileId: patientProfileId,
            lessonId: lessonId,
            repsCompleted: repsCompleted,
            repsTarget: reps,
            elapsedSeconds: currentElapsedSeconds(),
            status: status
        )
        await OutboxSyncManager.shared.processQueueIfOnline()
        await CacheService.shared.invalidate(CacheKey.lessonProgress(patientProfileId: patientProfileId))
        await CacheService.shared.invalidate(CacheKey.completionDates(patientProfileId: patientProfileId))
    }

    private func startSensorTimer() {
        sensorTimer?.invalidate()
        sensorTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.updateExtendSensor()
        }
        RunLoop.main.add(sensorTimer!, forMode: .common)
    }

    private func startElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedReferenceTime = Date()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedDisplaySeconds = currentElapsedSeconds()
        }
        RunLoop.main.add(elapsedTimer!, forMode: .common)
        elapsedDisplaySeconds = 0
    }

    private func currentElapsedSeconds() -> Int {
        guard let ref = elapsedReferenceTime else { return elapsedBaseSeconds }
        return elapsedBaseSeconds + Int(Date().timeIntervalSince(ref))
    }

    private func formatElapsed(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%dm %ds", m, s)
    }

    private func stopAll() {
        sensorTimer?.invalidate()
        sensorTimer = nil
        prepTimer?.invalidate()
        prepTimer = nil
        testSimTimer?.invalidate()
        testSimTimer = nil
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    private func startTestSimulationExtend() {
        testSimTimer?.invalidate()
        testSimFill = 0
        let start = Date()
        let rampDuration: Double = 2.5
        testSimTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            let elapsed = Date().timeIntervalSince(start)
            let newFill = Swift.min(1.0, elapsed / rampDuration)
            testSimFill = newFill
            updateExtendSensor()
            if newFill >= 1.0 {
                testSimTimer?.invalidate()
                testSimTimer = nil
            }
        }
        RunLoop.main.add(testSimTimer!, forMode: .common)
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

    // MARK: - Insights

    private func startInsights() async {
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

    private func finishInsights() {
        LessonSensorInsightsCollector.shared.updateProgress(
            repsCompleted: engine.repCount,
            totalDurationSec: currentElapsedSeconds()
        )
        LessonSensorInsightsCollector.shared.finishAndSaveDraft(completed: true)
    }
}
