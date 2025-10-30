import SwiftUI

struct PairDeviceSearchingView: View {
    @EnvironmentObject var router: Router
    var body: some View {
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
        .navigationTitle("Step 2")
    }
}