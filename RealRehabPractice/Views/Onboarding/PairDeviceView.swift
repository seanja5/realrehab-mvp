import SwiftUI

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
    
    private var isPairButtonDisabled: Bool {
        if case .scanning = state {
            return true
        }
        return false
    }
    
    var body: some View {
        VStack(spacing: 0) {
            StepIndicator(current: 2, total: 3, showLabel: true)
                .padding(.top, 8)
            
            ScrollView {
                VStack(spacing: 16) {
                    // Header content (always visible)
                    Image(systemName: "bluetooth")
                        .font(.system(size: 72))
                        .foregroundStyle(Color.brandLightBlue)
                    
                    Text("Searching for device...")
                        .font(.title3.weight(.semibold))
                    
                    Text("Make sure your device is powered on and within close proximity.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    // Devices Found section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Devices Found:")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider()
                        
                        if case .scanning = state {
                            // Empty area during scanning
                            Spacer()
                                .frame(height: 100)
                        } else if case .found(let devices) = state {
                            // Device list
                            ForEach(devices) { device in
                                HStack(spacing: 16) {
                                    // Left: Image placeholder
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gray.opacity(0.25))
                                        .frame(width: 72, height: 72)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundStyle(.gray)
                                        )
                                    
                                    // Right: Device info
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(device.name)
                                            .font(.headline)
                                        Text(device.kind)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                        Text("S/N: \(device.serial)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding(.top, 24)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            
            // Bottom button
            VStack {
                PrimaryButton(
                    title: "Pair Device!",
                    isDisabled: isPairButtonDisabled,
                    action: {
                        router.go(.calibrateDevice)
                    }
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .safeAreaPadding(.bottom)
        }
        .onAppear {
            // Simulate device discovery after 3.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                state = .found([
                    Device(name: "Knee Brace", kind: "Device", serial: "######")
                ])
            }
        }
    }
}

