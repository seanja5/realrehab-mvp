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
            // MARK: - Background: pure white top fading to deep navy
            LinearGradient(
                stops: [
                    .init(color: Color(red: 1.00, green: 1.00, blue: 1.00), location: 0.00),
                    .init(color: Color(red: 0.88, green: 0.88, blue: 0.90), location: 0.28),
                    .init(color: Color(red: 0.050, green: 0.100, blue: 0.310), location: 0.44),
                    .init(color: Color(red: 0.075, green: 0.160, blue: 0.460), location: 1.00)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Ambient glow in the dark lower portion only
            RadialGradient(
                colors: [Color(red: 0.28, green: 0.52, blue: 0.96).opacity(0.14), Color.clear],
                center: UnitPoint(x: 0.85, y: 0.82),
                startRadius: 0,
                endRadius: 300
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

                Spacer().frame(height: 40)

                // Login card
                VStack(spacing: 24) {
                    VStack(spacing: 6) {
                        Text("Welcome Back")
                            .font(.rrHeadline)
                            .foregroundStyle(.white)
                        Text("Sign in to continue your recovery")
                            .font(.rrCallout)
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    // Input fields
                    VStack(spacing: 14) {
                        DarkFormTextField(
                            placeholder: "Email address",
                            text: Binding(get: { auth.email }, set: { auth.email = $0 }),
                            icon: "envelope"
                        )
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()

                        DarkFormSecureField(
                            placeholder: "Password",
                            text: Binding(get: { auth.password }, set: { auth.password = $0 }),
                            icon: "lock"
                        )
                        .textContentType(.password)
                    }
                    .padding(.horizontal, 24)

                    // Buttons
                    VStack(spacing: 12) {
                        // Login — white pill outline on dark
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
                                .foregroundStyle((!isFormValid || auth.isLoading) ? Color.white.opacity(0.4) : Color.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity((!isFormValid || auth.isLoading) ? 0.06 : 0.12))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity((!isFormValid || auth.isLoading) ? 0.18 : 0.35), lineWidth: 1.5)
                                )
                        }
                        .buttonStyle(ScaleButtonStyle())
                        .disabled(!isFormValid || auth.isLoading)
                        .padding(.horizontal, 24)

                        // Divider
                        HStack {
                            Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
                            Text("or")
                                .font(.rrCaption)
                                .foregroundStyle(.white.opacity(0.35))
                                .padding(.horizontal, 12)
                            Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
                        }
                        .padding(.horizontal, 32)

                        // Get Started — electric blue gradient pill
                        Button(action: { router.go(.createAccount) }) {
                            Text("Create Account")
                                .font(.rrBody)
                                .fontWeight(.semibold)
                                .tracking(0.2)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(
                                    LinearGradient(
                                        colors: [Color.brandDarkBlue, Color(red: 0.18, green: 0.36, blue: 0.78)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(Capsule())
                                .shadow(color: Color.brandDarkBlue.opacity(0.5), radius: 12, x: 0, y: 5)
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

// MARK: - Dark-themed form field (icon + text, glass background)
private struct DarkFormTextField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 20)
            TextField(placeholder, text: $text)
                .font(.rrBody)
                .foregroundStyle(.white)
                .tint(.white)
                .placeholder(when: text.isEmpty) {
                    Text(placeholder).foregroundStyle(.white.opacity(0.35))
                }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct DarkFormSecureField: View {
    let placeholder: String
    @Binding var text: String
    var icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 20)
            SecureField(placeholder, text: $text)
                .font(.rrBody)
                .foregroundStyle(.white)
                .tint(.white)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - Placeholder helper
private extension View {
    func placeholder<Content: View>(when shouldShow: Bool, @ViewBuilder placeholder: () -> Content) -> some View {
        ZStack(alignment: .leading) {
            if shouldShow { placeholder() }
            self
        }
    }
}
