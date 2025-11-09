import SwiftUI

struct SelectLoginView: View {
    @EnvironmentObject var router: Router
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            PrimaryButton(title: "Patient Login") {
                router.go(.patientLogin)
            }
            .padding(.horizontal, 24)
            
            SecondaryButton(title: "PT Login") {
                router.go(.ptLogin)
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .rrPageBackground()
        .navigationTitle("Login")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
    }
}

