import SwiftUI

struct AllSetView: View {
    @EnvironmentObject var router: Router
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        Text("Complete")
                            .font(.rrTitle)
                        StepIndicator(current: 3, total: 3, showLabel: false)
                    }
                    .padding(.top, 8)
                    
                    VStack(spacing: 24) {
                        Spacer()
                            .frame(minHeight: 40)
                        Text("You're All Set!")
                            .font(.rrHeadline)
                        Spacer()
                            .frame(minHeight: 40)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            
            // Bottom button
            VStack {
                PrimaryButton(title: "Get Started!") {
                    router.go(.home)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .safeAreaPadding(.bottom)
        }
        .rrPageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
    }
}
