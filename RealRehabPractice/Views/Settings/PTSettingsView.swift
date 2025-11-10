import SwiftUI

struct PTSettingsView: View {
    @EnvironmentObject private var router: Router
    @State private var notifySessionComplete = true
    @State private var notifyMissedDay = false

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
        }
    }

    private var accountSection: some View {
        settingsCard(title: "Account") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
                Text("Dr. Taylor Logan")
                    .font(.rrBody)

                Divider()

                Text("Email")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
                Text("taylor.logan@realrehab.com")
                    .font(.rrBody)

                Divider()

                Text("Phone")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
                Text("(555) 987-6543")
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
            VStack(alignment: .leading, spacing: 8) {
                Text("Clinic")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
                Text("TODO")
                    .font(.rrBody)
                    .foregroundStyle(.secondary)
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
}

struct PTSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PTSettingsView()
                .environmentObject(Router())
        }
    }
}

