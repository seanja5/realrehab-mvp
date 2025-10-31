import SwiftUI

struct PairDeviceFoundView: View {
    @EnvironmentObject var router: Router
    var body: some View {
        VStack(spacing: 16) {
            Text("Devices Found:")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            RoundedRectangle(cornerRadius: 12)
                .fill(.gray.opacity(0.15))
                .frame(height: 80)
                .overlay(Text("Knee Brace Device\nS/N: ######").padding(), alignment: .leading)
            Spacer()
            Button("Pair Device!") { router.go(.calibrateDevice) }
                .buttonStyle(.borderedProminent).controlSize(.large)
        }
        .padding()
        .navigationTitle("Step 2")
    }
}
