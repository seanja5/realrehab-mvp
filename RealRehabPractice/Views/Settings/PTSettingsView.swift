import SwiftUI

struct PTSettingsView: View {
    @EnvironmentObject private var router: Router
    @EnvironmentObject private var session: SessionContext
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @State private var notifySessionComplete = true
    @State private var notifyMissedDay = false
    @State private var notifyMessages = true
    @State private var skipNextNotifySave = false
    @State private var ptProfile: PTService.PTProfileRow? = nil
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var npiVerification: NPIVerificationService.VerificationResult? = nil
    /// True when we should show the offline/stale banner (offline and either data is stale or user tried to refresh).
    @State private var showOfflineBanner = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    OfflineStaleBanner(showBanner: !networkMonitor.isOnline && showOfflineBanner)
                    if ptProfile == nil && errorMessage == nil {
                        skeletonContent
                    } else {
                    VStack(spacing: 24) {
                        accountSection
                        practiceSection
                        notificationsSection
                        dangerZoneSection
                        testAnalyticsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                    }
                }
                .padding(.top, RRSpace.pageTop)
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
        .task {
            await loadProfile(forceRefresh: false)
        }
        .refreshable {
            await loadProfile(forceRefresh: true)
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

    private var skeletonContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Skeleton: Account card
            VStack(alignment: .leading, spacing: 16) {
                SkeletonBlock(width: 80, height: 22)
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonBlock(width: 200, height: 14)
                    SkeletonBlock(width: 160, height: 16)
                    SkeletonBlock(width: 220, height: 14)
                    SkeletonBlock(width: 180, height: 16)
                    SkeletonBlock(width: 120, height: 14)
                    SkeletonBlock(width: 140, height: 16)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(white: 0.94))
                        .shimmer()
                )
            }
            // Skeleton: Practice card
            VStack(alignment: .leading, spacing: 16) {
                SkeletonBlock(width: 100, height: 22)
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.88))
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                    .shimmer()
            }
            // Skeleton: Notifications card
            VStack(alignment: .leading, spacing: 16) {
                SkeletonBlock(width: 130, height: 22)
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.88))
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .shimmer()
            }
            // Skeleton: Danger zone card
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
        SettingsSection(title: "Account", innerSpacing: 8) {
            LabeledValueRow(label: "Name", value: displayName)
            Divider()
            LabeledValueRow(label: "Email", value: ptProfile?.email ?? "—")
            Divider()
            LabeledValueRow(label: "Phone", value: ptProfile?.phone ?? "—")
            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Verification")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
                Text(verificationStatusText)
                    .font(.rrBody)
                    .foregroundStyle(verificationStatusColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var notificationsSection: some View {
        SettingsSection(title: "Notifications") {
            Toggle(isOn: $notifySessionComplete) {
                Text("Patient session completed")
                    .font(.rrBody)
            }
            .onChange(of: notifySessionComplete) { _, _ in saveNotificationPreferences() }

            Divider()

            Toggle(isOn: $notifyMissedDay) {
                Text("Missed day reminders")
                    .font(.rrBody)
            }
            .onChange(of: notifyMissedDay) { _, _ in saveNotificationPreferences() }

            Divider()

            Toggle(isOn: $notifyMessages) {
                Text("Messages")
                    .font(.rrBody)
            }
            .onChange(of: notifyMessages) { _, _ in saveNotificationPreferences() }
        }
        .toggleStyle(SwitchToggleStyle(tint: Color.brandDarkBlue))
    }

    private var practiceSection: some View {
        SettingsSection(title: "Practice", innerSpacing: 8) {
            LabeledValueRow(label: "Practice/Clinic Name", value: ptProfile?.practice_name ?? "—")
            Divider()
            LabeledValueRow(label: "Practice Address", value: ptProfile?.practice_address ?? "—")
            Divider()
            LabeledValueRow(label: "Specialization", value: ptProfile?.specialization ?? "—")
            Divider()
            LabeledValueRow(label: "License Number", value: ptProfile?.license_number ?? "—")
            Divider()
            LabeledValueRow(label: "NPI Number", value: ptProfile?.npi_number ?? "—")
        }
    }

    private var dangerZoneSection: some View {
        SettingsSection(title: "Sign out") {
            DestructiveButton(title: "Sign out") {
                Task {
                    try? await AuthService.signOut()
                    router.reset(to: .welcome)
                }
            }
        }
    }

    private var testAnalyticsSection: some View {
        SettingsSection(title: "Testing") {
            Button {
                router.go(.ptLessonAnalytics(lessonTitle: "Knee Extension", lessonId: nil, patientProfileId: nil))
            } label: {
                Text("Test Analytics")
                    .font(.rrBody)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 16)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
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
    
    private var verificationStatusText: String {
        switch npiVerification {
        case .verified: return "Verified"
        case .notVerified: return "Not Verified"
        case .error: return "Unable to verify"
        case .none: return "—"
        }
    }
    
    private var verificationStatusColor: Color {
        switch npiVerification {
        case .verified: return Color.brandDarkBlue
        case .notVerified: return .secondary
        case .error, .none: return .secondary
        }
    }

    private func loadProfile(forceRefresh: Bool = false) async {
        guard session.ptProfileId != nil else {
            errorMessage = "PT profile not available"
            return
        }
        
        if ptProfile == nil {
            isLoading = true
        }
        showOfflineBanner = false
        
        do {
            let (profile, isStale) = try await PTService.myPTProfileForDisplay()
            self.ptProfile = profile
            skipNextNotifySave = true
            self.notifySessionComplete = profile.notifySessionComplete
            self.notifyMissedDay = profile.notifyMissedDay
            self.notifyMessages = profile.notifyMessages
            // Show banner when offline and (data is stale or user explicitly tried to refresh)
            self.showOfflineBanner = !NetworkMonitor.shared.isOnline && (isStale || forceRefresh)
            await checkNPIVerification()
        } catch {
            if error is CancellationError || Task.isCancelled {
                return
            }
            if ptProfile == nil {
                debugLog("❌ PTSettingsView.loadProfile error: \(error)")
                errorMessage = error.localizedDescription
            }
        }
        isLoading = false
    }
    
    private func checkNPIVerification() async {
        guard let profile = ptProfile,
              let npi = profile.npi_number,
              !npi.trimmingCharacters(in: .whitespaces).isEmpty else {
            npiVerification = .notVerified
            return
        }
        let result = await NPIVerificationService.verify(
            npi: npi,
            firstName: profile.first_name,
            lastName: profile.last_name
        )
        npiVerification = result
    }
    
    private func saveNotificationPreferences() {
        guard !skipNextNotifySave else {
            skipNextNotifySave = false
            return
        }
        guard let ptId = session.ptProfileId else {
            debugLog("⚠️ PTSettingsView.saveNotificationPreferences: no ptProfileId")
            return
        }
        Task { @MainActor in
            do {
                try await PTService.updateNotificationPreferences(ptProfileId: ptId, notifySessionComplete: notifySessionComplete, notifyMissedDay: notifyMissedDay, notifyMessages: notifyMessages)
            } catch {
                errorMessage = error.localizedDescription
                debugLog("❌ PTSettingsView.saveNotificationPreferences: \(error)")
            }
        }
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
