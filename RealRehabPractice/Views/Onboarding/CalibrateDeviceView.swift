import SwiftUI
import CoreBluetooth

// ⚠️ TEST MODE — set to false to restore real BLE calibration before release
private let testMode = true

struct CalibrateDeviceView: View {
    let reps: Int?
    let restSec: Int?
    let lessonId: UUID?
    let lessonTitle: String?
    let fromUnpause: Bool
    let onFinish: (() -> Void)?
    @EnvironmentObject var router: Router

    /// 45 for Short Arc Quad, 90 for all other exercises.
    private var startingAngleDeg: Int {
        (lessonTitle?.lowercased().contains("short arc") == true) ? 45 : 90
    }

    init(reps: Int? = nil, restSec: Int? = nil, lessonId: UUID? = nil, lessonTitle: String? = nil, fromUnpause: Bool = false, onFinish: (() -> Void)? = nil) {
        self.reps = reps
        self.restSec = restSec
        self.lessonId = lessonId
        self.lessonTitle = lessonTitle
        self.fromUnpause = fromUnpause
        self.onFinish = onFinish
    }

    @StateObject private var ble = BluetoothManager.shared
    @State private var startSet = false
    @State private var maxSet = false
    @State private var startingPositionValue: Int? = nil
    @State private var maximumPositionValue: Int? = nil
    @State private var isSavingStarting = false
    @State private var isSavingMaximum = false
    @State private var errorMessage: String? = nil

    // Calibration constants for degree conversion
    private let minSensorValue: Int = 185
    private let sensorRange: Int = 115
    private let minDegrees: Double = 90.0
    private let degreeRange: Double = 90.0

    private func convertToDegrees(_ sensorValue: Int) -> Int {
        let degrees = minDegrees + (Double(sensorValue - minSensorValue) / Double(sensorRange)) * degreeRange
        return Int(degrees.rounded())
    }

    private var currentDegrees: Int? {
        guard let flexValue = ble.currentFlexSensorValue else { return nil }
        return convertToDegrees(flexValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: RRSpace.section) {
                    Text("Calibrate Device")
                        .font(.rrHeadline)

                    if testMode {
                        HStack(spacing: 8) {
                            Image(systemName: "testtube.2")
                            Text("Test Mode — Auto-Calibrated")
                                .font(.rrCallout)
                        }
                        .foregroundStyle(Color.brandDarkBlue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.brandDarkBlue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else if fromUnpause {
                        Text("Since you paused the lesson, we need to recalibrate your brace so it collects accurate information on your movement.")
                            .font(.rrCallout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else {
                        Text("Set your movement range so tracking is accurate.")
                            .font(.rrCallout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Divider().padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: RRSpace.stack) {
                        if !testMode {
                            if let degrees = currentDegrees {
                                HStack {
                                    Text("Current Knee Bend Angle (Degrees):")
                                        .font(.rrBody)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(degrees)")
                                        .font(.rrTitle)
                                        .foregroundStyle(.primary)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            } else {
                                HStack {
                                    Text("Waiting for flex sensor data...")
                                        .font(.rrBody)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }

                        Text("Relax your leg until your knee is bent at roughly a \(startingAngleDeg)-degree angle. When you're ready, tap Set Starting Position.")
                            .font(.rrBody)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)

                        SecondaryButton(title: startSet ? "Starting Position ✓" : "Set Starting Position") {
                            if testMode {
                                startingPositionValue = startingAngleDeg
                                startSet = true
                            } else if let currentValue = ble.currentFlexSensorValue {
                                let degrees = convertToDegrees(currentValue)
                                startingPositionValue = degrees
                                startSet = true
                                Task { await saveCalibration(stage: "starting_position", flexValue: degrees) }
                            } else {
                                errorMessage = "No flex sensor value available. Please ensure your device is connected."
                            }
                        }
                        .disabled(isSavingStarting)

                        if let v = startingPositionValue {
                            Text("Starting position: \(v)°")
                                .font(.rrBody)
                                .foregroundStyle(.primary)
                                .padding(.leading, 16)
                        }

                        Text("Now slowly extend your leg as far as you comfortably can, then tap Set Maximum Position.")
                            .font(.rrBody)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)

                        SecondaryButton(title: maxSet ? "Maximum Position ✓" : "Set Maximum Position") {
                            if testMode {
                                maximumPositionValue = 180
                                maxSet = true
                            } else if let currentValue = ble.currentFlexSensorValue {
                                let degrees = convertToDegrees(currentValue)
                                maximumPositionValue = degrees
                                maxSet = true
                                Task { await saveCalibration(stage: "maximum_position", flexValue: degrees) }
                            } else {
                                errorMessage = "No flex sensor value available. Please ensure your device is connected."
                            }
                        }
                        .disabled(isSavingMaximum)

                        if let v = maximumPositionValue {
                            Text("Maximum position: \(v)°")
                                .font(.rrBody)
                                .foregroundStyle(.primary)
                                .padding(.leading, 16)
                        }

                        if let error = errorMessage {
                            Text(error)
                                .font(.rrCaption)
                                .foregroundStyle(.red)
                                .padding(.top, 8)
                        }
                    }

                    Spacer().frame(minHeight: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, RRSpace.pageTop)
                .padding(.bottom, 40)
            }

            VStack {
                PrimaryButton(
                    title: "Finish Calibration!",
                    isDisabled: !(startSet && maxSet),
                    useLargeFont: true,
                    action: {
                        if fromUnpause, let finish = onFinish {
                            finish()
                        } else if lessonId != nil {
                            router.go(.directionsView1(reps: reps, restSec: restSec, lessonId: lessonId, lessonTitle: lessonTitle))
                        } else {
                            router.go(.journeyMap)
                        }
                    }
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .safeAreaPadding(.bottom)
        }
        .rrPageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Calibration")
        .navigationBarBackButtonHidden(true)
        .swipeToGoBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { BackButton() }
        }
        .onAppear {
            if testMode {
                // Auto-complete calibration — no BLE needed
                startingPositionValue = startingAngleDeg
                startSet = true
                maximumPositionValue = 180
                maxSet = true
            }
        }
        .onChange(of: ble.currentFlexSensorValue) { _, newValue in
            guard !testMode, let value = newValue else { return }
            debugLog("📊 CalibrateDeviceView: Flex sensor value updated: \(value) → \(convertToDegrees(value))°")
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let error = errorMessage { Text(error) }
        }
    }

    private func saveCalibration(stage: String, flexValue: Int) async {
        guard let peripheral = ble.connectedPeripheral else {
            await MainActor.run { errorMessage = "No device connected. Please pair a device first." }
            return
        }
        let bluetoothIdentifier = peripheral.identifier.uuidString
        await MainActor.run {
            if stage == "starting_position" { isSavingStarting = true } else { isSavingMaximum = true }
            errorMessage = nil
        }
        do {
            try await TelemetryService.saveCalibration(bluetoothIdentifier: bluetoothIdentifier, stage: stage, flexValue: flexValue)
            await MainActor.run {
                if stage == "starting_position" { isSavingStarting = false } else { isSavingMaximum = false }
            }
        } catch {
            await MainActor.run {
                if stage == "starting_position" { isSavingStarting = false } else { isSavingMaximum = false }
                errorMessage = "Failed to save calibration: \(error.localizedDescription)"
            }
        }
    }
}
