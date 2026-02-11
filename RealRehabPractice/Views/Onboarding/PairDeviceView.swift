import SwiftUI
import CoreBluetooth
import Combine

enum ScanState {
    case scanning
    case found([Device])
}

struct Device: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let kind: String
    let serial: String
}

struct PairDeviceView: View {
    @EnvironmentObject var router: Router
    @State private var state: ScanState = .scanning
    @StateObject private var ble = BluetoothManager.shared

    private var isPairButtonDisabled: Bool {
        if case .scanning = state {
            return true
        }
        return false
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: RRSpace.section) {
                    Text(ble.isScanning ? "Searching for devices…" : "Select a device to pair")
                        .font(.rrTitle)

                    Text("Make sure your device is powered on and within close proximity.")
                        .font(.rrCallout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: RRSpace.stack) {
                        HStack {
                            Text("Devices Found:")
                                .font(.rrTitle)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                ble.stopScan()
                                ble.startScan(targetNamePrefix: "RealRehab")
                            } label: {
                                Text("Search Again")
                                    .font(.rrCaption)
                                    .foregroundStyle(Color.brandDarkBlue)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.brandDarkBlue, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }

                        Divider()

                        if ble.peripherals.isEmpty {
                            Spacer()
                                .frame(height: 100)
                        } else {
                            ForEach(ble.peripherals) { peripheral in
                                HStack(spacing: 16) {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gray.opacity(0.25))
                                        .frame(width: 72, height: 72)
                                        .overlay(
                                            Image("kneebrace")
                                                .resizable()
                                                .scaledToFill()
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        )

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(peripheral.name)
                                            .font(.rrTitle)
                                        Text("RSSI: \(peripheral.rssi)")
                                            .font(.rrCallout)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .onTapGesture {
                                    ble.connect(peripheral)
                                    presentPairing(for: peripheral)
                                }
                            }
                        }
                    }
                    .padding(.top, 24)

                    if let error = ble.lastError {
                        Text(error)
                            .font(.rrCaption)
                            .foregroundStyle(.red)
                    }

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }

            VStack {
                PrimaryButton(
                    title: "Pair Device!",
                    isDisabled: isPairButtonDisabled,
                    useLargeFont: true,
                    action: {
                        // Connect to the first available RealRehab device
                        if let firstDevice = ble.peripherals.first {
                            print("🔵 PairDeviceView: Pair button tapped, connecting to '\(firstDevice.name)'")
                            ble.connect(firstDevice)
                            // Wait a moment for connection, then navigate
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                router.go(.calibrateDevice)
                            }
                        } else {
                            print("⚠️ PairDeviceView: No devices available to connect")
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
        .navigationTitle("Pair Device")
        .navigationBarBackButtonHidden(true)
        .swipeToGoBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
        .task {
            ble.startScan(targetNamePrefix: "RealRehab")
        }
        .onDisappear {
            ble.stopScan()
        }
        .onChange(of: ble.peripherals) { oldValue, newValue in
            if let match = newValue.first {
                presentPairing(for: match)
            }
        }
    }

    private func presentPairing(for peripheral: BluetoothManager.DiscoveredPeripheral) {
        // Maintain compatibility with the existing pairing flow by updating local state
        state = .found([
            Device(name: peripheral.name, kind: "Device", serial: peripheral.id.uuidString)
        ])
    }
}

