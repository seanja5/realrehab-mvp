import SwiftUI

struct PatientSettingsView: View {
    @EnvironmentObject private var router: Router
    @State private var allowReminders = true
    @State private var allowCamera = false
    @State private var patientProfile: PatientService.PatientProfileRow? = nil
    @State private var email: String? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 24) {
                    accountSection
                    notificationsSection
                    dangerZoneSection
                }
                .padding(.horizontal, 20)
                .padding(.top, RRSpace.pageTop)
                .padding(.bottom, 120)
            }
            .rrPageBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)

            PatientTabBar(
                selected: .settings,
                onSelect: handleSelect(tab:),
                onAddTapped: handleAddTapped
            )
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .navigationBarBackButtonHidden(true)
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
                labeledValue(label: "Name", value: displayName)
                Divider()
                labeledValue(label: "Email", value: email ?? "—")
                Divider()
                labeledValue(label: "Phone", value: patientProfile?.phone ?? "—")
                Divider()
                labeledValue(label: "Date of Birth", value: formattedDate(patientProfile?.date_of_birth))
                Divider()
                labeledValue(label: "Gender", value: patientProfile?.gender ?? "—")
                if let surgeryDate = patientProfile?.surgery_date, !surgeryDate.isEmpty {
                    Divider()
                    labeledValue(label: "Date of Surgery", value: formattedDate(surgeryDate))
                }
                if let lastVisit = patientProfile?.last_pt_visit, !lastVisit.isEmpty {
                    Divider()
                    labeledValue(label: "Last PT Visit", value: formattedDate(lastVisit))
                }
            }
        }
    }
    
    private var displayName: String {
        guard let profile = patientProfile else { return "—" }
        let first = profile.first_name ?? ""
        let last = profile.last_name ?? ""
        if first.isEmpty && last.isEmpty {
            return "—"
        }
        return "\(first) \(last)".trimmingCharacters(in: .whitespaces)
    }
    
    private func formattedDate(_ dateString: String?) -> String {
        guard let dateString = dateString, !dateString.isEmpty else {
            return "—"
        }
        
        let inputFormatter = ISO8601DateFormatter()
        inputFormatter.formatOptions = [.withFullDate]
        
        guard let date = inputFormatter.date(from: dateString) else {
            return dateString
        }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateStyle = .medium
        return outputFormatter.string(from: date)
    }

    private var notificationsSection: some View {
        settingsCard(title: "Notifications") {
            Toggle(isOn: $allowReminders) {
                Text("Allow reminders")
                    .font(.rrBody)
            }
            
            Divider()
            
            Toggle(isOn: $allowCamera) {
                Text("Allow camera")
                    .font(.rrBody)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: .brandDarkBlue))
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

    private func labeledValue(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.rrCaption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.rrBody)
        }
    }

    private func handleSelect(tab: PatientTab) {
        switch tab {
        case .dashboard:
            router.goWithoutAnimation(.ptDetail)
        case .journey:
            router.goWithoutAnimation(.journeyMap)
        case .settings:
            break
        }
    }

    private func handleAddTapped() {
        router.go(.pairDevice)
    }
    
    private func loadProfile() async {
        isLoading = true
        errorMessage = nil
        do {
            let profile = try await PatientService.myPatientProfile()
            self.patientProfile = profile
            
            // Fetch email from profiles table
            if let profileId = profile.profile_id {
                self.email = try await PatientService.getEmail(profileId: profileId)
            }
        } catch {
            print("❌ PatientSettingsView.loadProfile error: \(error)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

struct PatientSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PatientSettingsView()
                .environmentObject(Router())
        }
    }
}

