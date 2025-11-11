import SwiftUI
import Combine

struct LoginView: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var session: SessionContext
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
                title: auth.isLoading ? "Logging in..." : "Log In",
                isDisabled: !isFormValid || auth.isLoading,
                useLargeFont: true
            ) {
                Task {
                    await auth.signIn()
                    if auth.errorMessage == nil {
                        do {
                            // Resolve IDs after login
                            let ids = try await AuthService.resolveIdsForCurrentUser()
                            session.profileId = ids.profileId
                            session.ptProfileId = ids.ptProfileId
                            print("✅ Login resolved IDs: profile=\(ids.profileId?.uuidString ?? "nil"), pt_profile=\(ids.ptProfileId?.uuidString ?? "nil")")
                            
                            let (profileId, role) = try await AuthService.myProfileIdAndRole()
                            switch role {
                            case "pt":
                                router.go(.patientList)
                            case "patient":
                                router.go(.ptDetail)
                            default:
                                auth.errorMessage = "Account setup incomplete. Please finish your profile."
                            }
                        } catch {
                            auth.errorMessage = error.localizedDescription
                        }
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

