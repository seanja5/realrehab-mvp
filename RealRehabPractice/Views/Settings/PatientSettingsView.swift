import SwiftUI
import Supabase
import PostgREST

struct PatientSettingsView: View {
    @EnvironmentObject private var router: Router
    @State private var allowReminders = true
    @State private var allowCamera = false
    @State private var patientProfile: PatientService.PatientProfileRow? = nil
    @State private var email: String? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var hasPT: Bool = false
    @State private var accessCode: String = ""
    @State private var isPairing: Bool = false
    @FocusState private var isAccessCodeFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 24) {
                    accountSection
                    notificationsSection
                    if !hasPT {
                        connectPTSection
                    }
                    dangerZoneSection
                }
                .padding(.horizontal, 20)
                .padding(.top, RRSpace.pageTop)
                .padding(.bottom, 120)
            }
            .scrollDismissesKeyboard(.interactively)
            .rrPageBackground()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    BluetoothStatusIndicator()
                }
            }

            PatientTabBar(
                selected: .settings,
                onSelect: handleSelect(tab:),
                onAddTapped: handleAddTapped
            )
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .navigationBarBackButtonHidden(true)
        .task {
            await loadProfile()
            await checkIfHasPT()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .onDisappear {
            // Clear error message when navigating away to prevent showing cancelled errors
            errorMessage = nil
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

    private var connectPTSection: some View {
        settingsCard(title: "Connect with your PT") {
            VStack(alignment: .leading, spacing: 12) {
                Text("If your Physical Therapist provided you with an 8-digit access code, enter it here to link your account.")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Access Code")
                        .font(.rrCaption)
                        .foregroundStyle(.secondary)
                    
                    TextField("Enter 8-digit code", text: $accessCode)
                        .font(.rrBody)
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .focused($isAccessCodeFocused)
                        .keyboardType(.numberPad)
                        .onChange(of: accessCode) { oldValue, newValue in
                            // Limit to 8 digits and only allow numbers
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered.count <= 8 {
                                accessCode = filtered
                            } else {
                                accessCode = String(filtered.prefix(8))
                            }
                        }
                }
                
                PrimaryButton(
                    title: isPairing ? "Connecting..." : "Connect",
                    isDisabled: accessCode.count != 8 || isPairing,
                    action: {
                        Task {
                            await connectWithPT()
                        }
                    }
                )
            }
        }
    }
    
    private var dangerZoneSection: some View {
        settingsCard(title: "Sign out") {
            Button {
                Task {
                    try? await AuthService.signOut()
                    router.reset(to: .welcome)
                }
            } label: {
                Text("Sign out")
                    .font(.rrBody)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.red, lineWidth: 1)
                    )
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
            // Ignore cancellation errors when navigating quickly
            if error is CancellationError || Task.isCancelled {
                return
            }
            print("❌ PatientSettingsView.loadProfile error: \(error)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func checkIfHasPT() async {
        do {
            guard let profile = try await AuthService.myProfile() else {
                hasPT = false
                return
            }
            
            // Check if patient has a PT by trying to get patient profile ID and checking for mapping
            if let patientProfileId = try? await PatientService.myPatientProfileId(profileId: profile.id) {
                // Check if there's a PT mapping
                struct MapRow: Decodable {
                    let pt_profile_id: UUID
                }
                
                let mapRows: [MapRow] = try await SupabaseService.shared.client
                    .schema("accounts")
                    .from("pt_patient_map")
                    .select("pt_profile_id")
                    .eq("patient_profile_id", value: patientProfileId.uuidString)
                    .limit(1)
                    .decoded()
                
                hasPT = mapRows.first != nil
            } else {
                hasPT = false
            }
        } catch {
            // Ignore cancellation errors when navigating quickly
            if error is CancellationError || Task.isCancelled {
                return
            }
            print("❌ PatientSettingsView.checkIfHasPT error: \(error)")
            hasPT = false
        }
    }
    
    private func connectWithPT() async {
        guard accessCode.count == 8 else {
            errorMessage = "Please enter a valid 8-digit access code"
            return
        }
        
        isPairing = true
        errorMessage = nil
        
        do {
            // Get current patient's profile ID
            guard let profile = try await AuthService.myProfile() else {
                errorMessage = "Profile not found. Please try again."
                isPairing = false
                return
            }
            
            guard let currentPatientProfileId = try? await PatientService.myPatientProfileId(profileId: profile.id) else {
                // If patient profile doesn't exist, we need to create it first
                // This shouldn't happen if they're in settings, but handle it anyway
                errorMessage = "Patient profile not found. Please contact support."
                isPairing = false
                return
            }
            
            // Link patient via access code - this updates the placeholder and prevents duplicates
            try await PatientService.linkPatientViaAccessCode(
                accessCode: accessCode,
                patientProfileId: currentPatientProfileId
            )
            
            // Success! Clear access code and update hasPT
            accessCode = ""
            hasPT = true
            
            print("✅ PatientSettingsView: Successfully connected patient to PT")
        } catch {
            // Ignore cancellation errors when navigating quickly
            if error is CancellationError || Task.isCancelled {
                isPairing = false
                return
            }
            print("❌ PatientSettingsView.connectWithPT error: \(error)")
            errorMessage = "Failed to connect: \(error.localizedDescription)"
        }
        
        isPairing = false
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

