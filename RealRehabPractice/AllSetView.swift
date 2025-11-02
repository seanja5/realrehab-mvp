import SwiftUI

struct AllSetView: View {
    @EnvironmentObject var router: Router
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text("Complete")
                    .font(.headline)
                StepIndicator(current: 3, total: 3, showLabel: false)
            }
            .padding(.top, 8)
            
            VStack(spacing: 24) {
                Spacer()
                Text("You're All Set!").font(.title.weight(.bold))
                Spacer()
                Button("Get Started!") { router.go(.home) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }
            .padding()
        }
    }
}
