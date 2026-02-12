import SwiftUI
import Supabase
import PostgREST

struct PatientSettingsView: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var pendingLinkStore: PendingLinkStore
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @State private var allowReminders = false
    @State private var allowCamera = false
    @State private var patientProfile: PatientService.PatientProfileRow? = nil
    @State private var email: String? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var hasPT: Bool = false
    @State private var accessCode: String = ""
    @State private var isPairing: Bool = false
    @State private var hasLoadedInitial = false  // Skip onChange when loading (prevents offline error)
    @State private var showOfflineBanner = false
    @FocusState private var isAccessCodeFocused: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    OfflineStaleBanner(showBanner: !networkMonitor.isOnline && showOfflineBanner)
                    if patientProfile == nil && errorMessage == nil {
                        skeletonContent
                    } else {
                    VStack(spacing: 24) {
                        accountSection
                        notificationsSection
                    if !hasPT {
                        connectPTSection
                    }
                    dangerZoneSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 120)
                    }
                }
                .padding(.top, RRSpace.pageTop)
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
            await loadProfile(forceRefresh: false)
            await checkIfHasPT()
        }
        .onAppear {
            if let code = pendingLinkStore.code, code.count <= 8 {
                accessCode = String(code.prefix(8))
                pendingLinkStore.clearCode()
            }
        }
        .refreshable {
            await loadProfile(forceRefresh: true)
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
        .bluetoothPopupOverlay()
    }

    private var skeletonContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                SkeletonBlock(width: 80, height: 22)
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.88))
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .shimmer()
            }
            VStack(alignment: .leading, spacing: 16) {
                SkeletonBlock(width: 130, height: 22)
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.88))
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .shimmer()
            }
            VStack(alignment: .leading, spacing: 16) {
                SkeletonBlock(width: 70, height: 22)
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.88))
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .shimmer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 120)
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
        
        // Parse as local date to avoid timezone shifts
        guard let date = Date.fromDateOnlyString(dateString) else {
            return dateString
        }
        
        let outputFormatter = DateFormatter()
        outputFormatter.dateStyle = .medium
        outputFormatter.timeZone = TimeZone.current
        return outputFormatter.string(from: date)
    }

    private var notificationsSection: some View {
        settingsCard(title: "Notifications") {
            Toggle(isOn: $allowReminders) {
                Text("Allow reminders")
                    .font(.rrBody)
            }
            .onChange(of: allowReminders) { _, enabled in
                guard hasLoadedInitial else { return }  // Skip when loading from cache (prevents offline error)
                Task { await saveRemindersPreference(enabled: enabled) }
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
    
    private func loadProfile(forceRefresh: Bool = false) async {
        if patientProfile == nil && (email?.isEmpty ?? true) {
            isLoading = true
        }
        errorMessage = nil
        showOfflineBanner = false
        do {
            let (profile, isStale) = try await PatientService.myPatientProfileForDisplay()
            self.patientProfile = profile
            
            if let profileId = profile.profile_id {
                self.email = try? await PatientService.getEmail(profileId: profileId)
            }
            let remindersEnabled = (try? await PatientService.getScheduleRemindersEnabled(patientProfileId: profile.id)) ?? false
            await MainActor.run { allowReminders = remindersEnabled }
            self.showOfflineBanner = !NetworkMonitor.shared.isOnline && (isStale || forceRefresh)
        } catch {
            if error is CancellationError || Task.isCancelled {
                return
            }
            if patientProfile == nil {
                print("❌ PatientSettingsView.loadProfile error: \(error)")
                errorMessage = error.localizedDescription
            }
        }
        hasLoadedInitial = true
        isLoading = false
    }
    
    private func checkIfHasPT() async {
        do {
            guard let profile = try await AuthService.myProfile() else {
                hasPT = false
                return
            }
            
            // Use PatientService.hasPT (disk-cached) so data persists when switching tabs/offline
            if let patientProfileId = try? await PatientService.myPatientProfileId(profileId: profile.id) {
                hasPT = (try? await PatientService.hasPT(patientProfileId: patientProfileId)) ?? false
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
    
    private func saveRemindersPreference(enabled: Bool) async {
        guard let patientProfileId = patientProfile?.id else { return }
        do {
            try await PatientService.setScheduleRemindersEnabled(patientProfileId: patientProfileId, enabled: enabled)
            if enabled {
                let profile = try await AuthService.myProfile()
                let slots = try await ScheduleService.getSchedule(patientProfileId: patientProfileId)
                let granted = await NotificationManager.requestAuthorizationIfNeeded()
                if granted, !slots.isEmpty {
                    await NotificationManager.scheduleScheduleReminders(slots: slots, firstName: profile?.first_name)
                }
            } else {
                await NotificationManager.cancelScheduleReminders()
            }
        } catch {
            // Don't show error when offline - save will sync when back online
            guard NetworkMonitor.shared.isOnline else { return }
            await MainActor.run { errorMessage = error.localizedDescription }
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

