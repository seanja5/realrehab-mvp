import SwiftUI

struct PTSettingsView: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var session: SessionContext
    @State private var notifySessionComplete = true
    @State private var notifyMissedDay = false
    @State private var ptProfile: PTService.PTProfileRow? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 24) {
                    accountSection
                    notificationsSection
                    practiceSection
                    dangerZoneSection
                }
                .padding(.horizontal, 20)
                .padding(.top, RRSpace.pageTop)
                .padding(.bottom, 120)
            }
            .rrPageBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)

            PTTabBar(selected: .settings) { tab in
                switch tab {
                case .dashboard:
                    router.goWithoutAnimation(.patientList)
                case .settings:
                    break
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
        .task {
            await loadProfile()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var accountSection: some View {
        settingsCard(title: "Account") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
                Text(displayName)
                    .font(.rrBody)

                Divider()

                Text("Email")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
                Text(ptProfile?.email ?? "—")
                    .font(.rrBody)

                Divider()

                Text("Phone")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
                Text(ptProfile?.phone ?? "—")
                    .font(.rrBody)

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Verification")
                            .font(.rrCaption)
                            .foregroundStyle(.secondary)
                        Text("Verified")
                            .font(.rrBody)
                            .foregroundStyle(Color.brandDarkBlue)
                    }
                    Spacer()
                    Button("Manage") {
                        // TODO: manage profile
                    }
                    .font(.rrBody)
                    .foregroundStyle(Color.brandDarkBlue)
                }
            }
        }
    }

    private var notificationsSection: some View {
        settingsCard(title: "Notifications") {
            Toggle(isOn: $notifySessionComplete) {
                Text("Patient session completed")
                    .font(.rrBody)
            }

            Divider()

            Toggle(isOn: $notifyMissedDay) {
                Text("Missed day reminders")
                    .font(.rrBody)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: Color.brandDarkBlue))
    }

    private var practiceSection: some View {
        settingsCard(title: "Practice") {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Practice/Clinic Name")
                        .font(.rrCaption)
                        .foregroundStyle(.secondary)
                    Text(ptProfile?.practice_name ?? "—")
                        .font(.rrBody)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Practice Address")
                        .font(.rrCaption)
                        .foregroundStyle(.secondary)
                    Text(ptProfile?.practice_address ?? "—")
                        .font(.rrBody)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Specialization")
                        .font(.rrCaption)
                        .foregroundStyle(.secondary)
                    Text(ptProfile?.specialization ?? "—")
                        .font(.rrBody)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("License Number")
                        .font(.rrCaption)
                        .foregroundStyle(.secondary)
                    Text(ptProfile?.license_number ?? "—")
                        .font(.rrBody)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("NPI Number")
                        .font(.rrCaption)
                        .foregroundStyle(.secondary)
                    Text(ptProfile?.npi_number ?? "—")
                        .font(.rrBody)
                }
            }
        }
    }

    private var dangerZoneSection: some View {
        settingsCard(title: "Sign out") {
            PrimaryButton(title: "Sign out") {
                Task {
                    try? await AuthService.signOut()
                    router.reset(to: .welcome)
                }
            }
        }
    }
    
    private var displayName: String {
        guard let profile = ptProfile else { return "—" }
        let first = profile.first_name ?? ""
        let last = profile.last_name ?? ""
        if first.isEmpty && last.isEmpty {
            return "—"
        }
        return "\(first) \(last)".trimmingCharacters(in: .whitespaces)
    }

    @ViewBuilder
    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.rrHeadline)

            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
            )
        }
    }
    
    private func loadProfile() async {
        guard session.ptProfileId != nil else {
            errorMessage = "PT profile not available"
            return
        }
        
        isLoading = true
        do {
            let profile = try await PTService.myPTProfile()
            self.ptProfile = profile
        } catch {
            print("❌ PTSettingsView.loadProfile error: \(error)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct PTSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PTSettingsView()
                .environmentObject(Router())
                .environmentObject(SessionContext())
        }
    }
}
