import SwiftUI

struct PTLoginView: View {
    @EnvironmentObject var router: Router
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var phone = ""
    @State private var email = ""
    
    private let fieldFill = Color(uiColor: .secondarySystemFill)
    
    private var isFormValid: Bool {
        !firstName.isEmpty &&
        !lastName.isEmpty &&
        !phone.isEmpty &&
        !email.isEmpty
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Title
                Text("Login")
                    .font(.rrHeadline)
                    .padding(.top, RRSpace.pageTop)
                
                VStack(spacing: 16) {
                    // First Name / Last Name
                    HStack(spacing: 12) {
                        FormTextField(title: "First Name", placeholder: "First Name", text: $firstName)
                            .textContentType(.givenName)
                            .autocapitalization(.words)
                            .frame(maxWidth: .infinity)
                        FormTextField(title: "Last Name", placeholder: "Last Name", text: $lastName)
                            .textContentType(.familyName)
                            .autocapitalization(.words)
                            .frame(maxWidth: .infinity)
                    }
                    
                    FormTextField(title: "Phone", placeholder: "Phone", text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    
                    FormTextField(title: "Email", placeholder: "Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .ignoresSafeArea(.keyboard)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(
                title: "Login",
                isDisabled: !isFormValid,
                useLargeFont: true
            ) {
                if isFormValid {
                    router.go(.patientList)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
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

// MARK: - Form Field Helper
private func FormTextField(title: String, placeholder: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(.rrCaption)
            .foregroundStyle(.secondary)
        
        TextField(placeholder, text: text)
            .font(.rrBody)
            .padding(14)
            .background(Color(uiColor: .secondarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

