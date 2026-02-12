//
//  AssessmentView.swift
//  RealRehabPractice
//
//  Created by Sean Andrews on 12/7/25.
//

import SwiftUI
import CoreBluetooth

struct AssessmentView: View {
    let lessonId: UUID?
    @EnvironmentObject var router: Router
    @StateObject private var ble = BluetoothManager.shared
    
    init(lessonId: UUID? = nil) {
        self.lessonId = lessonId
    }
    @State private var maxSet = false
    @State private var maximumPositionValue: Int? = nil
    @State private var isSavingMaximum = false
    @State private var errorMessage: String? = nil
    
    // Calibration constants for degree conversion (same as CalibrateDeviceView)
    private let minSensorValue: Int = 185  // 90 degrees (midpoint of 180-190 range)
    private let maxSensorValue: Int = 300  // 180 degrees
    private let minDegrees: Double = 90.0
    private let maxDegrees: Double = 180.0
    private let sensorRange: Int = 115  // 300 - 185 = 115
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

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: RRSpace.section) {
                    Text("Reassessment")
                        .font(.rrHeadline)
                    Text("Let's see if your maximum extension range has increased")
                        .font(.rrCallout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Divider()
                        .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: RRSpace.stack) {
                        // Live knee bend angle display
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
                        
                        Text("Now slowly extend your leg as far as you comfortably can, then tap Set Maximum Position.")
                            .font(.rrBody)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)

                        SecondaryButton(title: maxSet ? "Maximum Position ✓" : "Set Maximum Position") {
                            if let currentValue = ble.currentFlexSensorValue {
                                let degrees = convertToDegrees(currentValue)
                                maximumPositionValue = degrees
                                maxSet = true
                                print("✅ AssessmentView: Set Maximum Position button clicked - Saved flex sensor value: \(currentValue) → \(degrees) degrees")
                                
                                // Save to database (save degrees, not raw value)
                                Task {
                                    await saveCalibration(stage: "maximum_position", flexValue: degrees)
                                }
                            } else {
                                print("⚠️ AssessmentView: Set Maximum Position button clicked - No flex sensor value available")
                                errorMessage = "No flex sensor value available. Please ensure your device is connected."
                            }
                        }
                        .disabled(isSavingMaximum)
                        
                        if let maximumValue = maximumPositionValue {
                            Text("Maximum position: \(maximumValue)")
                                .font(.rrBody)
                                .foregroundStyle(.primary)
                                .padding(.leading, 16)
                        }
                        
                        // Error message display
                        if let error = errorMessage {
                            Text(error)
                                .font(.rrCaption)
                                .foregroundStyle(.red)
                                .padding(.top, 8)
                        }
                    }
                    Spacer()
                        .frame(minHeight: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, RRSpace.pageTop)
                .padding(.bottom, 40)
            }

            VStack {
                PrimaryButton(
                    title: "Finish Assessment!",
                    isDisabled: !maxSet,
                    useLargeFont: true,
                    action: {
                        router.go(.completion(lessonId: lessonId))
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
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }
    
    // Save calibration to database
    private func saveCalibration(stage: String, flexValue: Int) async {
        // Get Bluetooth peripheral identifier
        guard let peripheral = ble.connectedPeripheral else {
            await MainActor.run {
                errorMessage = "No device connected. Please pair a device first."
            }
            return
        }
        
        let bluetoothIdentifier = peripheral.identifier.uuidString
        
        // Set saving state
        await MainActor.run {
            isSavingMaximum = true
            errorMessage = nil
        }
        
        do {
            try await TelemetryService.saveCalibration(
                bluetoothIdentifier: bluetoothIdentifier,
                stage: stage,
                flexValue: flexValue
            )
            
            await MainActor.run {
                isSavingMaximum = false
                print("✅ AssessmentView: Successfully saved \(stage) calibration with flex_value: \(flexValue)")
            }
        } catch {
            await MainActor.run {
                isSavingMaximum = false
                errorMessage = "Failed to save calibration: \(error.localizedDescription)"
                print("❌ AssessmentView: Failed to save \(stage) calibration: \(error)")
            }
        }
    }
}

