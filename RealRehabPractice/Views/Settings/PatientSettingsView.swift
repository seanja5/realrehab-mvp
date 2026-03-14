import SwiftUI
import Supabase
import PostgREST

struct PatientSettingsView: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var pendingLinkStore: PendingLinkStore
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @State private var allowReminders = false
    @State private var allowCamera = false
    @State private var notifyMessages = true
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
            VStack(alignment: .leading, spacing: 10) {
                SkeletonBlock(width: 70, height: 14)
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(white: 0.88))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .shimmer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 120)
    }

    private var accountSection: some View {
        SettingsSection(title: "Account", innerSpacing: 8) {
            LabeledValueRow(label: "Name", value: displayName)
            Divider()
            LabeledValueRow(label: "Email", value: email ?? "—")
            Divider()
            LabeledValueRow(label: "Phone", value: patientProfile?.phone ?? "—")
            Divider()
            LabeledValueRow(label: "Date of Birth", value: formattedDate(patientProfile?.date_of_birth))
            Divider()
            LabeledValueRow(label: "Gender", value: patientProfile?.gender ?? "—")
            if let surgeryDate = patientProfile?.surgery_date, !surgeryDate.isEmpty {
                Divider()
                LabeledValueRow(label: "Date of Surgery", value: formattedDate(surgeryDate))
            }
            if let lastVisit = patientProfile?.last_pt_visit, !lastVisit.isEmpty {
                Divider()
                LabeledValueRow(label: "Last PT Visit", value: formattedDate(lastVisit))
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
        SettingsSection(title: "Notifications") {
            Toggle(isOn: $allowReminders) {
                Text("Allow reminders")
                    .font(.rrBody)
            }
            .onChange(of: allowReminders) { _, enabled in
                guard hasLoadedInitial else { return }
                Task { await saveRemindersPreference(enabled: enabled) }
            }

            Divider()

            Toggle(isOn: $allowCamera) {
                Text("Allow camera")
                    .font(.rrBody)
            }

            Divider()

            Toggle(isOn: $notifyMessages) {
                Text("Messages")
                    .font(.rrBody)
            }
            .onChange(of: notifyMessages) { _, enabled in
                guard hasLoadedInitial else { return }
                Task { await saveMessageNotificationsPreference(enabled: enabled) }
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: .brandDarkBlue))
    }

    private var connectPTSection: some View {
        SettingsSection(title: "Connect with your PT") {
            VStack(alignment: .leading, spacing: 12) {
                Text("If your Physical Therapist provided you with an 8-digit access code, enter it here to link your account.")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("ACCESS CODE")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.8)
                        .foregroundStyle(Color.secondary.opacity(0.75))

                    TextField("Enter 8-digit code", text: $accessCode)
                        .font(.rrBody)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.03), radius: 4, x: 0, y: 2)
                        .focused($isAccessCodeFocused)
                        .keyboardType(.numberPad)
                        .onChange(of: accessCode) { oldValue, newValue in
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
        VStack(alignment: .leading, spacing: 10) {
            Text("SIGN OUT")
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(Color(red: 0.50, green: 0.53, blue: 0.62))
                .padding(.leading, 4)
            DestructiveButton(title: "Sign out") {
                Task {
                    try? await AuthService.signOut()
                    router.reset(to: .welcome)
                }
            }
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
            let messagesEnabled = (try? await PatientService.getMessageNotificationsEnabled(patientProfileId: profile.id)) ?? true
            await MainActor.run { notifyMessages = messagesEnabled }
            self.showOfflineBanner = !NetworkMonitor.shared.isOnline && (isStale || forceRefresh)
        } catch {
            if error is CancellationError || Task.isCancelled {
                return
            }
            if patientProfile == nil {
                debugLog("❌ PatientSettingsView.loadProfile error: \(error)")
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
            debugLog("❌ PatientSettingsView.checkIfHasPT error: \(error)")
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

    private func saveMessageNotificationsPreference(enabled: Bool) async {
        guard let patientProfileId = patientProfile?.id else { return }
        do {
            try await PatientService.setMessageNotificationsEnabled(patientProfileId: patientProfileId, enabled: enabled)
        } catch {
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
            
            debugLog("✅ PatientSettingsView: Successfully connected patient to PT")
        } catch {
            // Ignore cancellation errors when navigating quickly
            if error is CancellationError || Task.isCancelled {
                isPairing = false
                return
            }
            debugLog("❌ PatientSettingsView.connectWithPT error: \(error)")
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

