import SwiftUI

struct AllSetView: View {
    @EnvironmentObject var router: Router
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer()
                        .frame(minHeight: 40)
                    Text("You're All Set!")
                        .font(.rrHeadline)
                    Spacer()
                        .frame(minHeight: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, RRSpace.pageTop)
                .padding(.bottom, 40)
            }

            VStack {
                PrimaryButton(title: "Get Started!", useLargeFont: true) {
                    router.go(.ptDetail)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .safeAreaPadding(.bottom)
        }
        .rrPageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Complete")
        .navigationBarBackButtonHidden(true)
        .swipeToGoBack()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
    }
}
