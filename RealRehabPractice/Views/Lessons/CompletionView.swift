import SwiftUI

struct CompletionView: View {
    @EnvironmentObject var router: Router
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Title group
                Text("You Did It!")
                    .font(.rrHeadline)
                    .padding(.top, RRSpace.pageTop)
                
                // Spacer to push metrics down
                Spacer(minLength: 100)
                
                // Metrics stack - centered, one per row
                VStack(spacing: 16) {
                    // Session card
                    HStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.rrBody)
                            .foregroundStyle(.primary)
                        Text("Session: 7 min")
                            .font(.rrTitle)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 18)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                    )
                    
                    // Range card
                    HStack(spacing: 12) {
                        Image(systemName: "chart.pie")
                            .font(.rrBody)
                            .foregroundStyle(.primary)
                        Text("Range: +8°")
                            .font(.rrTitle)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 18)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                    )
                    
                    // Accuracy card
                    HStack(spacing: 12) {
                        Image(systemName: "chart.bar.fill")
                            .font(.rrBody)
                            .foregroundStyle(.primary)
                        Text("Accuracy: 93%")
                            .font(.rrTitle)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 18)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(Color.black.opacity(0.05), lineWidth: 1)
                    )
                }
                .frame(maxWidth: 360)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .safeAreaInset(edge: .bottom) {
            // Bottom buttons
            VStack(spacing: 12) {
                PrimaryButton(title: "Back to Journey Map") {
                    router.go(.journeyMap)
                }
                
                SecondaryButton(title: "Back to Home") {
                    router.go(.home)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .background(.ultraThinMaterial)
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
