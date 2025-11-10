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
            ScrollView {
                VStack(spacing: RRSpace.section) {
                    Image(systemName: "bluetooth")
                        .font(.system(size: 72))
                        .foregroundStyle(Color.brandLightBlue)
                    
                    Text("Searching for device...")
                        .font(.rrTitle)
                    
                    Text("Make sure your device is powered on and within close proximity.")
                        .font(.rrCallout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    VStack(alignment: .leading, spacing: RRSpace.stack) {
                        Text("Devices Found:")
                            .font(.rrTitle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider()
                        
                        if case .scanning = state {
                            Spacer()
                                .frame(height: 100)
                        } else if case .found(let devices) = state {
                            ForEach(devices) { device in
                                HStack(spacing: 16) {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.gray.opacity(0.25))
                                        .frame(width: 72, height: 72)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundStyle(.gray)
                                        )
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(device.name)
                                            .font(.rrTitle)
                                        Text(device.kind)
                                            .font(.rrCallout)
                                            .foregroundStyle(.secondary)
                                        Text("S/N: \(device.serial)")
                                            .font(.rrCallout)
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
            
            VStack {
                PrimaryButton(
                    title: "Pair Device!",
                    isDisabled: isPairButtonDisabled,
                    useLargeFont: true,
                    action: {
                        router.go(.calibrateDevice)
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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                state = .found([
                    Device(name: "Knee Brace", kind: "Device", serial: "######")
                ])
            }
        }
    }
}

