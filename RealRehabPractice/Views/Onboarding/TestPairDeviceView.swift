import SwiftUI

// Test version of PairDeviceView that bypasses Bluetooth
// Shows a hardcoded device immediately for testing Supabase uploads
struct TestPairDeviceView: View {
    @EnvironmentObject var router: Router
    @State private var isPairing = false
    
    // Hardcoded test device
    private let testDevice = TestDevice(
        id: UUID(),
        name: "RealRehab Test Device",
        kind: "Test Device",
        serial: "TEST-DEVICE-12345"
    )
    
    struct TestDevice: Identifiable {
        let id: UUID
        let name: String
        let kind: String
        let serial: String
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: RRSpace.section) {
                    Image(systemName: "bluetooth")
                        .font(.system(size: 72))
                        .foregroundStyle(Color.brandLightBlue)

                    Text("Test Device Pairing")
                        .font(.rrTitle)

                    Text("This is a test view that bypasses Bluetooth. A test device is shown automatically.")
                        .font(.rrCallout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    VStack(alignment: .leading, spacing: RRSpace.stack) {
                        HStack {
                            Text("Test Device:")
                                .font(.rrTitle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Divider()

                        // Show hardcoded test device
                        HStack(spacing: 16) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.gray.opacity(0.25))
                                .frame(width: 72, height: 72)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundStyle(.gray)
                                )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(testDevice.name)
                                    .font(.rrTitle)
                                Text("Serial: \(testDevice.serial)")
                                    .font(.rrCallout)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .padding(.top, 24)

                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }

            VStack {
                PrimaryButton(
                    title: isPairing ? "Pairing..." : "Pair Test Device!",
                    isDisabled: isPairing,
                    useLargeFont: true,
                    action: {
                        isPairing = true
                        print("🔵 TestPairDeviceView: Pair button tapped for test device '\(testDevice.name)'")
                        
                        // Simulate pairing delay, then navigate to calibration
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isPairing = false
                            router.go(.calibrateDevice(reps: nil, restSec: nil, lessonId: nil))
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
        .navigationTitle("Test Pair Device")
        .navigationBarBackButtonHidden(true)
        .swipeToGoBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
    }
}

