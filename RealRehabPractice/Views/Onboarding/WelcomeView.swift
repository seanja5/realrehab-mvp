import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var router: Router
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()
                
                // Centered Title Section
                VStack(alignment: .center, spacing: 3) {
                    Text("Real")
                        .font(.system(size: 46, weight: .bold))
                        .foregroundStyle(Color.brandLightBlue)
                    Text("Rehab")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(Color.brandDarkBlue)
                }
                
                Spacer()
                
                // Action Buttons - pinned to bottom
                VStack(spacing: 20) {
                    PrimaryButton(title: "Get Started!", action: {
                        router.go(.selectSignUp)
                    })
                    
                    SecondaryButton(title: "Log In", action: {
                        router.go(.login)
                    })
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
                .safeAreaPadding(.bottom)
            }
        }
        .rrPageBackground()
        .navigationBarBackButtonHidden(true)
    }
}
