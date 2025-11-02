import SwiftUI

struct CalibrateDeviceView: View {
    @EnvironmentObject var router: Router
    @State private var startSet = false
    @State private var maxSet = false

    var body: some View {
        VStack(spacing: 0) {
            StepIndicator(current: 3, total: 3, showLabel: true)
                .padding(.top, 8)
            
            VStack(spacing: 16) {
                Text("Calibrate Device").font(.title2.weight(.bold))
                Text("Set your movement range so tracking is accurate.")
                    .foregroundStyle(.secondary).multilineTextAlignment(.center)
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    Button(startSet ? "Starting Position ✓" : "Set Starting Position") { startSet = true }
                        .buttonStyle(.borderedProminent)
                    Button(maxSet ? "Maximum Position ✓" : "Set Maximum Position") { maxSet = true }
                        .buttonStyle(.bordered)
                }
                Spacer()
                Button("Finish Calibration!") { router.go(.allSet) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }
            .padding()
        }
    }
}