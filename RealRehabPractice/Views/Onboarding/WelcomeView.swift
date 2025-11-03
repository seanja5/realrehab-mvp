import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var router: Router
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()
                
                // Centered Title Section
                VStack(alignment: .center, spacing: 4) {
                    Text("Real")
                        .font(.system(size: 36, weight: .bold, design: .default))
                        .foregroundStyle(Color.brandLightBlue)
                    Text("Rehab")
                        .font(.system(size: 36, weight: .bold, design: .default))
                        .foregroundStyle(Color.brandDarkBlue)
                }
                
                Spacer()
                
                // Action Buttons - pinned to bottom
                VStack(spacing: 20) {
                    PrimaryButton(title: "Get Started!", action: {
                        router.go(.createAccount)
                    })
                    
                    SecondaryButton(title: "Log In", action: {
                        router.go(.home)
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
