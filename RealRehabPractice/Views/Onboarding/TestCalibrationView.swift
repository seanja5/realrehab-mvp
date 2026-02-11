import SwiftUI

struct TestCalibrationView: View {
    @EnvironmentObject var router: Router
    @State private var startSet = false
    @State private var maxSet = false
    @State private var startingPositionValue: Int? = nil
    @State private var maximumPositionValue: Int? = nil
    @State private var isSavingStarting = false
    @State private var isSavingMaximum = false
    @State private var errorMessage: String? = nil
    
    // Hardcoded test values
    private let testStartingValue = 110
    private let testMaximumValue = 400
    private let testBluetoothIdentifier = "TEST-DEVICE-12345" // Fake Bluetooth identifier for testing

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: RRSpace.section) {
                    Text("Test Calibration")
                        .font(.rrHeadline)
                    Text("Test Supabase upload with hardcoded values.")
                        .font(.rrCallout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Divider()
                        .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: RRSpace.stack) {
                        // Display test values
                        HStack {
                            Text("Test Flex Sensor Value:")
                                .font(.rrBody)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(startSet && maxSet ? "\(testMaximumValue)" : startSet ? "\(testStartingValue)" : "—")
                                .font(.rrTitle)
                                .foregroundStyle(.primary)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                        
                        Text("Click 'Set Starting Position' to test saving value 110 to Supabase.")
                            .font(.rrBody)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)

                        SecondaryButton(title: startSet ? "Starting Position ✓" : "Set Starting Position") {
                            startingPositionValue = testStartingValue
                            startSet = true
                            print("✅ TestCalibrationView: Set Starting Position button clicked - Test value: \(testStartingValue)")
                            
                            // Save to database
                            Task {
                                await saveCalibration(stage: "starting_position", flexValue: testStartingValue)
                            }
                        }
                        .disabled(isSavingStarting)
                        
                        if let startingValue = startingPositionValue {
                            Text("Starting position: \(startingValue)")
                                .font(.rrBody)
                                .foregroundStyle(.primary)
                                .padding(.leading, 16)
                        }

                        Text("Click 'Set Maximum Position' to test saving value 400 to Supabase.")
                            .font(.rrBody)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)

                        SecondaryButton(title: maxSet ? "Maximum Position ✓" : "Set Maximum Position") {
                            maximumPositionValue = testMaximumValue
                            maxSet = true
                            print("✅ TestCalibrationView: Set Maximum Position button clicked - Test value: \(testMaximumValue)")
                            
                            // Save to database
                            Task {
                                await saveCalibration(stage: "maximum_position", flexValue: testMaximumValue)
                            }
                        }
                        .disabled(isSavingMaximum)
                        
                        if let maximumValue = maximumPositionValue {
                            Text("Maximum position: \(maximumValue)")
                                .font(.rrBody)
                                .foregroundStyle(.primary)
                                .padding(.leading, 16)
                        }
                        
                        // Success/Error message display
                        if let error = errorMessage {
                            Text(error)
                                .font(.rrCaption)
                                .foregroundStyle(.red)
                                .padding(.top, 8)
                        } else if startSet && maxSet && !isSavingStarting && !isSavingMaximum {
                            Text("✅ Both values saved successfully! Check Supabase to verify.")
                                .font(.rrCaption)
                                .foregroundStyle(.green)
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
                    title: "Done Testing",
                    isDisabled: false,
                    useLargeFont: true,
                    action: {
                        router.go(.allSet)
                    }
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .safeAreaPadding(.bottom)
        }
        .rrPageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Test Calibration")
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
    
    // Save calibration to database (same as CalibrateDeviceView but with test Bluetooth ID)
    private func saveCalibration(stage: String, flexValue: Int) async {
        // Set saving state
        await MainActor.run {
            if stage == "starting_position" {
                isSavingStarting = true
            } else {
                isSavingMaximum = true
            }
            errorMessage = nil
        }
        
        do {
            try await TelemetryService.saveCalibration(
                bluetoothIdentifier: testBluetoothIdentifier,
                stage: stage,
                flexValue: flexValue
            )
            
            await MainActor.run {
                if stage == "starting_position" {
                    isSavingStarting = false
                } else {
                    isSavingMaximum = false
                }
                print("✅ TestCalibrationView: Successfully saved \(stage) calibration with flex_value: \(flexValue)")
            }
        } catch {
            await MainActor.run {
                if stage == "starting_position" {
                    isSavingStarting = false
                } else {
                    isSavingMaximum = false
                }
                errorMessage = "Failed to save calibration: \(error.localizedDescription)"
                print("❌ TestCalibrationView: Failed to save \(stage) calibration: \(error)")
            }
        }
    }
}

