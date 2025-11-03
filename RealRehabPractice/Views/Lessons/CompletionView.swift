import SwiftUI

struct CompletionView: View {
    @EnvironmentObject var router: Router
    var body: some View {
        ScrollView {
            VStack(spacing: RRSpace.section) {
                Text("You Did It!")
                    .font(.rrHeadline)
                HStack {
                    Label("Session: 7 min", systemImage: "clock")
                        .font(.rrCallout)
                        .padding(12)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Spacer()
                    Label("Range: +8°", systemImage: "chart.pie")
                        .font(.rrCallout)
                        .padding(12)
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                Label("Accuracy: 93%", systemImage: "chart.bar.fill")
                    .font(.rrCallout)
                    .padding(12)
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Divider()
                    .padding(.vertical)
                PrimaryButton(title: "Back to Home") {
                    router.reset(to: .home)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .rrPageBackground()
        .navigationTitle("Complete")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
    }
}