import SwiftUI

struct CompletionView: View {
    @EnvironmentObject var router: Router
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("You Did It!").font(.title.bold())
                HStack {
                    Label("Session: 7 min", systemImage: "clock")
                        .padding(12).background(.white).clipShape(RoundedRectangle(cornerRadius: 12))
                    Spacer()
                    Label("Range: +8°", systemImage: "chart.pie")
                        .padding(12).background(.white).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Label("Accuracy: 93%", systemImage: "chart.bar.fill")
                    .padding(12).background(.white).clipShape(RoundedRectangle(cornerRadius: 12))
                Divider().padding(.vertical)
                Button("Back to Home") { router.reset(to: .home) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }
            .padding()
        }
        .background(LinearGradient(colors: [.blue.opacity(0.25), .clear], startPoint: .top, endPoint: .center))
        .navigationTitle("Complete")
    }
}