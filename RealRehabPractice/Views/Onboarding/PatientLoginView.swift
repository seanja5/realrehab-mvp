import SwiftUI
import Combine

struct PatientLoginView: View {
    @EnvironmentObject private var router: Router
    @StateObject private var auth = AuthViewModel()
    
    private let fieldFill = Color(uiColor: .secondarySystemFill)
    
    private var isFormValid: Bool {
        !auth.email.isEmpty && !auth.password.isEmpty
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    FormTextField(
                        title: "Email",
                        placeholder: "Email",
                        text: Binding(
                            get: { auth.email },
                            set: { auth.email = $0 }
                        )
                    )
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()
                    
                    FormSecureField(
                        title: "Password",
                        placeholder: "Password",
                        text: Binding(
                            get: { auth.password },
                            set: { auth.password = $0 }
                        )
                    )
                    .textContentType(.password)
                }
                .padding(.horizontal, 20)
                .padding(.top, RRSpace.pageTop)
                .padding(.bottom, 40)
            }
        }
        .ignoresSafeArea(.keyboard)
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(
                title: auth.isLoading ? "Logging in..." : "Login",
                isDisabled: !isFormValid || auth.isLoading,
                useLargeFont: true
            ) {
                Task {
                    await auth.signIn()
                    if auth.errorMessage == nil {
                        router.go(.ptDetail)
                    }
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
        .alert(
            "Login Failed",
            isPresented: Binding(
                get: { auth.errorMessage != nil },
                set: { newValue in
                    if !newValue {
                        auth.errorMessage = nil
                    }
                }
            ),
            actions: {
                Button("OK", role: .cancel) {
                    auth.errorMessage = nil
                }
            },
            message: {
                Text(auth.errorMessage ?? "")
            }
        )
    }
    
    // MARK: - Helpers
    private func FormTextField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.rrCaption)
                .foregroundStyle(.secondary)
            
            TextField(placeholder, text: text)
                .font(.rrBody)
                .padding(14)
                .background(fieldFill)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
    
    private func FormSecureField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.rrCaption)
                .foregroundStyle(.secondary)
            
            SecureField(placeholder, text: text)
                .font(.rrBody)
                .padding(14)
                .background(fieldFill)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

