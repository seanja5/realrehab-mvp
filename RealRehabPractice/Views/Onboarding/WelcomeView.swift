import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject private var session: SessionContext
    @StateObject private var auth = AuthViewModel()
    @State private var logoVisible = false
    @State private var contentVisible = false

    private var isFormValid: Bool {
        !auth.email.isEmpty && !auth.password.isEmpty
    }

    var body: some View {
        ZStack {
            // MARK: - Background: page-background color fading to a very soft blue at bottom
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.978, green: 0.978, blue: 0.996), location: 0.00),
                    .init(color: Color(red: 0.966, green: 0.967, blue: 0.990), location: 0.25),
                    .init(color: Color(red: 0.945, green: 0.948, blue: 0.982), location: 0.50),
                    .init(color: Color(red: 0.920, green: 0.926, blue: 0.972), location: 0.75),
                    .init(color: Color(red: 0.898, green: 0.908, blue: 0.964), location: 1.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // MARK: - Content
            VStack(spacing: 0) {
                // Logo
                Image("LaunchLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300)
                    .scaleEffect(logoVisible ? 1.0 : 0.85)
                    .opacity(logoVisible ? 1.0 : 0.0)
                    .offset(y: -20)
                    .safeAreaPadding(.top)
                    .task {
                        withAnimation(RRAnimation.state) {
                            logoVisible = true
                        }
                        try? await Task.sleep(for: .milliseconds(150))
                        withAnimation(RRAnimation.gentle) {
                            contentVisible = true
                        }
                    }

                Spacer().frame(height: 32)

                // Login form
                VStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("Welcome Back")
                            .font(.rrHeadline)
                            .foregroundStyle(.primary)
                        Text("Sign in to continue your recovery")
                            .font(.rrCallout)
                            .foregroundStyle(.secondary)
                    }

                    // Input fields
                    VStack(spacing: 14) {
                        WelcomeFormField(
                            placeholder: "Email address",
                            icon: "envelope",
                            text: Binding(get: { auth.email }, set: { auth.email = $0 })
                        )
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()

                        WelcomeSecureField(
                            placeholder: "Password",
                            icon: "lock",
                            text: Binding(get: { auth.password }, set: { auth.password = $0 })
                        )
                        .textContentType(.password)
                    }
                    .padding(.horizontal, 24)

                    // Buttons
                    VStack(spacing: 10) {
                        // Sign In — primary gradient pill
                        Button(action: {
                            Task {
                                await auth.signIn()
                                if auth.errorMessage == nil {
                                    do {
                                        let ids = try await AuthService.resolveIdsForCurrentUser()
                                        session.profileId = ids.profileId
                                        session.ptProfileId = ids.ptProfileId
                                        debugLog("✅ Login resolved IDs: profile=\(ids.profileId?.uuidString ?? "nil"), pt_profile=\(ids.ptProfileId?.uuidString ?? "nil")")

                                        let (_, role) = try await AuthService.myProfileIdAndRole()
                                        await AuthService.cacheResolvedSession(profileId: ids.profileId!, ptProfileId: ids.ptProfileId, role: role)
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
                        }) {
                            Text(auth.isLoading ? "Signing in…" : "Sign In")
                                .font(.rrBody)
                                .fontWeight(.semibold)
                                .tracking(0.2)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(
                                    LinearGradient(
                                        colors: (!isFormValid || auth.isLoading)
                                            ? [Color.gray.opacity(0.45), Color.gray.opacity(0.35)]
                                            : [Color.brandDarkBlue, Color(red: 0.18, green: 0.36, blue: 0.78)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Capsule())
                                .shadow(color: (!isFormValid || auth.isLoading) ? .clear : Color.brandDarkBlue.opacity(0.35), radius: 10, x: 0, y: 4)
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(!isFormValid || auth.isLoading)
                        .padding(.horizontal, 24)

                        // Divider
                        HStack {
                            Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1)
                            Text("or")
                                .font(.rrCaption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                            Rectangle().fill(Color.black.opacity(0.08)).frame(height: 1)
                        }
                        .padding(.horizontal, 32)

                        // Create Account — outline secondary pill
                        Button(action: { router.go(.createAccount) }) {
                            Text("Create Account")
                                .font(.rrBody)
                                .fontWeight(.semibold)
                                .tracking(0.2)
                                .foregroundStyle(Color.brandDarkBlue)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(
                                    Capsule()
                                        .fill(Color.brandDarkBlue.opacity(0.06))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color.brandDarkBlue.opacity(0.55), lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .padding(.horizontal, 24)
                    }
                }
                .opacity(contentVisible ? 1.0 : 0.0)
                .offset(y: contentVisible ? 0 : 12)

                Spacer()
                    .frame(minHeight: 40)
                    .safeAreaPadding(.bottom)
            }
        }
        .navigationBarBackButtonHidden(true)
        .alert(
            "Login Failed",
            isPresented: Binding(
                get: { auth.errorMessage != nil },
                set: { newValue in
                    if !newValue { auth.errorMessage = nil }
                }
            ),
            actions: {
                Button("OK", role: .cancel) { auth.errorMessage = nil }
            },
            message: {
                Text(auth.errorMessage ?? "")
            }
        )
    }
}

// MARK: - Light-themed form fields (match CreateAccount style)
private struct WelcomeFormField: View {
    let placeholder: String
    let icon: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.secondary.opacity(0.6))
                .frame(width: 18)
            TextField(placeholder, text: $text)
                .font(.rrBody)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}

private struct WelcomeSecureField: View {
    let placeholder: String
    let icon: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.secondary.opacity(0.6))
                .frame(width: 18)
            SecureField(placeholder, text: $text)
                .font(.rrBody)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
    }
}
