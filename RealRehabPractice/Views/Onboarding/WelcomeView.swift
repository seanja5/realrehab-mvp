import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject private var session: SessionContext
    @StateObject private var auth = AuthViewModel()
    
    private let fieldFill = Color(uiColor: .secondarySystemFill)
    
    private var isFormValid: Bool {
        !auth.email.isEmpty && !auth.password.isEmpty
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Logo at top - positioned just below camera island (about 1 inch up)
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200)
                    .scaleEffect(1.3)
                    .offset(y: -20)
                    .safeAreaPadding(.top)
                
                // Spacing between logo and login content
                Spacer()
                    .frame(height: 40)
                
                // Login section - shifted up about 1 inch to center on screen
                VStack(spacing: 24) {
                    // Login title
                    Text("Login")
                        .font(.rrHeadline)
                        .foregroundStyle(.primary)
                    
                    // Input fields
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
                    
                    // Buttons section
                    VStack(spacing: 0) {
                        SecondaryButton(
                            title: auth.isLoading ? "Logging in..." : "Login",
                            isDisabled: !isFormValid || auth.isLoading,
                            action: {
                                Task {
                                    await auth.signIn()
                                    if auth.errorMessage == nil {
                                        do {
                                            // Resolve IDs after login
                                            let ids = try await AuthService.resolveIdsForCurrentUser()
                                            session.profileId = ids.profileId
                                            session.ptProfileId = ids.ptProfileId
                                            print("✅ Login resolved IDs: profile=\(ids.profileId?.uuidString ?? "nil"), pt_profile=\(ids.ptProfileId?.uuidString ?? "nil")")
                                            
                                            let (_, role) = try await AuthService.myProfileIdAndRole()
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
                        )
                        .padding(.horizontal, 24)
                        
                        Divider()
                            .background(Color.black.opacity(0.08))
                            .padding(.vertical, 12)
                            .padding(.horizontal, 40)
                        
                        PrimaryButton(title: "Get Started!", action: {
                            router.go(.selectSignUp)
                        })
                        .padding(.horizontal, 24)
                    }
                }
                
                // Bottom spacer - reduced to shift content up
                Spacer()
                    .frame(minHeight: 40)
                    .safeAreaPadding(.bottom)
            }
        }
        .rrPageBackground()
        .navigationBarBackButtonHidden(true)
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
    
    // MARK: - Form Field Helpers
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
