import SwiftUI

struct JourneyMapView: View {
    @EnvironmentObject var router: Router

    var body: some View {
        VStack(spacing: 24) {
            Text("Recovery Journey")
                .font(.title2.bold())
                .padding(.top, 20)

            // Placeholder visualization area
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.15))
                .frame(height: 240)
                .overlay(
                    VStack {
                        Image(systemName: "figure.walk.motion")
                            .font(.system(size: 48))
                            .foregroundColor(.blue)
                            .padding(.bottom, 8)
                        Text("Journey Progress Overview")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                )

            Spacer()

            // Single route to the lesson screen
            Button(action: {
                router.go(.lesson)
            }) {
                Text("Start Lesson")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .buttonStyle(.plain)

            Spacer()
        }
        .padding()
        .navigationTitle("Dashboard")
    }
}
