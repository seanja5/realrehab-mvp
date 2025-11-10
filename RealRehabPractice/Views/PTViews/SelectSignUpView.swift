import SwiftUI

struct SelectSignUpView: View {
    @EnvironmentObject var router: Router

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            PrimaryButton(title: "Patient SignUp") {
                router.go(.createAccount)
            }
            .padding(.horizontal, 24)

            SecondaryButton(title: "PT SignUp") {
                router.go(.ptCreateAccount)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .rrPageBackground()
        .navigationTitle("Select Sign Up")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
    }
}

