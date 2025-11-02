import SwiftUI

struct PairDeviceSearchingView: View {
    @EnvironmentObject var router: Router
    var body: some View {
        VStack(spacing: 0) {
            StepIndicator(current: 2, total: 3, showLabel: true)
                .padding(.top, 8)
            
            VStack(spacing: 16) {
                Text("Searching for device...")
                    .font(.title3.weight(.semibold))
                Text("Make sure your device is powered on and nearby.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
                Button("Simulate Found") { router.go(.pairDeviceFound) }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
    }
}