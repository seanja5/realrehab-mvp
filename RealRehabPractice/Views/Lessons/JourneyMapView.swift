import SwiftUI

struct JourneyMapView: View {
    @EnvironmentObject var router: Router

    var body: some View {
        ScrollView {
            VStack(spacing: RRSpace.section) {
                Text("Recovery Journey")
                    .font(.rrHeadline)
                    .padding(.top, RRSpace.pageTop)

                // Placeholder visualization area
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(0.15))
                    .frame(height: 240)
                    .overlay(
                        VStack {
                            Image(systemName: "figure.walk.motion")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.brandLightBlue)
                                .padding(.bottom, 8)
                            Text("Journey Progress Overview")
                                .font(.rrTitle)
                                .foregroundStyle(.secondary)
                        }
                    )

                Spacer()
                    .frame(minHeight: 40)

                PrimaryButton(title: "Start Lesson") {
                    router.go(.lesson)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .rrPageBackground()
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
    }
}
