import SwiftUI

struct PTSettingsView: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var session: SessionContext
    @State private var notifySessionComplete = true
    @State private var notifyMissedDay = false
    @State private var ptProfile: PTService.PTProfileRow? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var isEditing = false
    
    // Editable fields
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var practiceName: String = ""
    @State private var practiceAddress: String = ""
    @State private var specialization: String = ""
    @State private var licenseNumber: String = ""
    @State private var npiNumber: String = ""
    @State private var isSaving = false

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
                    router.go(.patientList)
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
            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button("Save") {
                        Task {
                            await saveProfile()
                        }
                    }
                    .disabled(isSaving)
                } else {
                    Button("Edit") {
                        isEditing = true
                    }
                }
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
                if isEditing {
                    HStack {
                        TextField("First Name", text: $firstName)
                            .textFieldStyle(.roundedBorder)
                        TextField("Last Name", text: $lastName)
                            .textFieldStyle(.roundedBorder)
                    }
                } else {
                    Text(displayName)
                        .font(.rrBody)
                }

                Divider()

                Text("Email")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
                if isEditing {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                } else {
                    Text(email.isEmpty ? "—" : email)
                        .font(.rrBody)
                }

                Divider()

                Text("Phone")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
                if isEditing {
                    TextField("Phone", text: $phone)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.phonePad)
                } else {
                    Text(phone.isEmpty ? "—" : phone)
                        .font(.rrBody)
                }

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
                    if isEditing {
                        TextField("Practice Name", text: $practiceName)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(practiceName.isEmpty ? "—" : practiceName)
                            .font(.rrBody)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Practice Address")
                        .font(.rrCaption)
                        .foregroundStyle(.secondary)
                    if isEditing {
                        TextField("Practice Address", text: $practiceAddress, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                    } else {
                        Text(practiceAddress.isEmpty ? "—" : practiceAddress)
                            .font(.rrBody)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Specialization")
                        .font(.rrCaption)
                        .foregroundStyle(.secondary)
                    if isEditing {
                        TextField("Specialization", text: $specialization)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(specialization.isEmpty ? "—" : specialization)
                            .font(.rrBody)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("License Number")
                        .font(.rrCaption)
                        .foregroundStyle(.secondary)
                    if isEditing {
                        TextField("License Number", text: $licenseNumber)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(licenseNumber.isEmpty ? "—" : licenseNumber)
                            .font(.rrBody)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("NPI Number")
                        .font(.rrCaption)
                        .foregroundStyle(.secondary)
                    if isEditing {
                        TextField("NPI Number", text: $npiNumber)
                            .textFieldStyle(.roundedBorder)
                    } else {
                        Text(npiNumber.isEmpty ? "—" : npiNumber)
                            .font(.rrBody)
                    }
                }
            }
        }
    }

    private var dangerZoneSection: some View {
        settingsCard(title: "Danger Zone") {
            PrimaryButton(title: "Sign out") {
                Task {
                    try? await AuthService.signOut()
                    router.reset(to: .welcome)
                }
            }
        }
    }
    
    private var displayName: String {
        let first = firstName.isEmpty ? "—" : firstName
        let last = lastName.isEmpty ? "—" : lastName
        if first == "—" && last == "—" {
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
            
            // Populate fields
            self.firstName = profile.first_name ?? ""
            self.lastName = profile.last_name ?? ""
            self.email = profile.email ?? ""
            self.phone = profile.phone ?? ""
            self.practiceName = profile.practice_name ?? ""
            self.practiceAddress = profile.practice_address ?? ""
            self.specialization = profile.specialization ?? ""
            self.licenseNumber = profile.license_number ?? ""
            self.npiNumber = profile.npi_number ?? ""
        } catch {
            print("❌ PTSettingsView.loadProfile error: \(error)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func saveProfile() async {
        guard let ptProfileId = session.ptProfileId else {
            errorMessage = "PT profile not available"
            return
        }
        
        isSaving = true
        do {
            try await PTService.updatePTProfile(
                ptProfileId: ptProfileId,
                email: email.isEmpty ? nil : email,
                firstName: firstName.isEmpty ? nil : firstName,
                lastName: lastName.isEmpty ? nil : lastName,
                phone: phone.isEmpty ? nil : phone,
                licenseNumber: licenseNumber.isEmpty ? nil : licenseNumber,
                npiNumber: npiNumber.isEmpty ? nil : npiNumber,
                practiceName: practiceName.isEmpty ? nil : practiceName,
                practiceAddress: practiceAddress.isEmpty ? nil : practiceAddress,
                specialization: specialization.isEmpty ? nil : specialization
            )
            isEditing = false
            // Reload to get updated data
            await loadProfile()
        } catch {
            print("❌ PTSettingsView.saveProfile error: \(error)")
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
        isSaving = false
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
