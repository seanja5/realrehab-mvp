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
                        Text(verificationStatusText)
                            .font(.rrBody)
                            .foregroundStyle(verificationStatusColor)
                    }
                    Spacer()
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
    
    private var testAnalyticsSection: some View {
        settingsCard(title: "Testing") {
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
                print("❌ PTSettingsView.loadProfile error: \(error)")
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
            print("⚠️ PTSettingsView.saveNotificationPreferences: no ptProfileId")
            return
        }
        Task { @MainActor in
            do {
                try await PTService.updateNotificationPreferences(ptProfileId: ptId, notifySessionComplete: notifySessionComplete, notifyMissedDay: notifyMissedDay, notifyMessages: notifyMessages)
            } catch {
                errorMessage = error.localizedDescription
                print("❌ PTSettingsView.saveNotificationPreferences: \(error)")
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
