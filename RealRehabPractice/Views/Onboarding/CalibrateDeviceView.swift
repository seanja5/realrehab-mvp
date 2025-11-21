import SwiftUI
import CoreBluetooth

struct CalibrateDeviceView: View {
    @EnvironmentObject var router: Router
    @StateObject private var ble = BluetoothManager.shared
    @State private var startSet = false
    @State private var maxSet = false
    @State private var startingPositionValue: Int? = nil
    @State private var maximumPositionValue: Int? = nil
    @State private var isSavingStarting = false
    @State private var isSavingMaximum = false
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: RRSpace.section) {
                    Text("Calibrate Device")
                        .font(.rrHeadline)
                    Text("Set your movement range so tracking is accurate.")
                        .font(.rrCallout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Divider()
                        .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: RRSpace.stack) {
                        // Live flex sensor value display
                        if let flexValue = ble.currentFlexSensorValue {
                            HStack {
                                Text("Current Flex Sensor Value:")
                                    .font(.rrBody)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(flexValue)")
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
                        
                        Text("Relax your leg until your knee is bent at roughly a 90-degree angle. When you're ready, tap Set Starting Position.")
                            .font(.rrBody)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)

                        SecondaryButton(title: startSet ? "Starting Position ✓" : "Set Starting Position") {
                            if let currentValue = ble.currentFlexSensorValue {
                                startingPositionValue = currentValue
                                startSet = true
                                print("✅ CalibrateDeviceView: Set Starting Position button clicked - Saved flex sensor value: \(currentValue)")
                                
                                // Save to database
                                Task {
                                    await saveCalibration(stage: "starting_position", flexValue: currentValue)
                                }
                            } else {
                                print("⚠️ CalibrateDeviceView: Set Starting Position button clicked - No flex sensor value available")
                                errorMessage = "No flex sensor value available. Please ensure your device is connected."
                            }
                        }
                        .disabled(isSavingStarting)
                        
                        if let startingValue = startingPositionValue {
                            Text("Starting position: \(startingValue)")
                                .font(.rrBody)
                                .foregroundStyle(.primary)
                                .padding(.leading, 16)
                        }

                        Text("Now slowly extend your leg as far as you comfortably can, then tap Set Maximum Position.")
                            .font(.rrBody)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)

                        SecondaryButton(title: maxSet ? "Maximum Position ✓" : "Set Maximum Position") {
                            if let currentValue = ble.currentFlexSensorValue {
                                maximumPositionValue = currentValue
                                maxSet = true
                                print("✅ CalibrateDeviceView: Set Maximum Position button clicked - Saved flex sensor value: \(currentValue)")
                                
                                // Save to database
                                Task {
                                    await saveCalibration(stage: "maximum_position", flexValue: currentValue)
                                }
                            } else {
                                print("⚠️ CalibrateDeviceView: Set Maximum Position button clicked - No flex sensor value available")
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
                    title: "Finish Calibration!",
                    isDisabled: !(startSet && maxSet),
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
        .navigationTitle("Calibration")
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
        .onAppear {
            print("📱 CalibrateDeviceView: View appeared")
            if let peripheral = ble.connectedPeripheral {
                print("✅ CalibrateDeviceView: Device is connected: \(peripheral.name ?? "Unknown")")
            } else {
                print("⚠️ CalibrateDeviceView: No device connected")
            }
            if let flexValue = ble.currentFlexSensorValue {
                print("📊 CalibrateDeviceView: Current flex sensor value: \(flexValue)")
            } else {
                print("⚠️ CalibrateDeviceView: No flex sensor value available yet")
            }
        }
        .onChange(of: ble.currentFlexSensorValue) { oldValue, newValue in
            if let value = newValue {
                print("📊 CalibrateDeviceView: Flex sensor value updated: \(value)")
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
            if stage == "starting_position" {
                isSavingStarting = true
            } else {
                isSavingMaximum = true
            }
            errorMessage = nil
        }
        
        do {
            try await TelemetryService.saveCalibration(
                bluetoothIdentifier: bluetoothIdentifier,
                stage: stage,
                flexValue: flexValue
            )
            
            await MainActor.run {
                if stage == "starting_position" {
                    isSavingStarting = false
                } else {
                    isSavingMaximum = false
                }
                print("✅ CalibrateDeviceView: Successfully saved \(stage) calibration with flex_value: \(flexValue)")
            }
        } catch {
            await MainActor.run {
                if stage == "starting_position" {
                    isSavingStarting = false
                } else {
                    isSavingMaximum = false
                }
                errorMessage = "Failed to save calibration: \(error.localizedDescription)"
                print("❌ CalibrateDeviceView: Failed to save \(stage) calibration: \(error)")
            }
        }
    }
}