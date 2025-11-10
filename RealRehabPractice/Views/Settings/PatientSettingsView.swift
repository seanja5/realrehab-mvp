import SwiftUI

struct PatientSettingsView: View {
    @EnvironmentObject private var router: Router
    @State private var allowReminders = true
    @State private var allowCamera = false

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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
    }

    private var accountSection: some View {
        settingsCard(title: "Account") {
            VStack(alignment: .leading, spacing: 8) {
                labeledValue(label: "Name", value: "Taylor Logan")
                Divider()
                labeledValue(label: "Email", value: "taylor.logan@realrehab.com")
                Divider()
                labeledValue(label: "Phone", value: "(555) 987-6543")
                Divider()
                labeledValue(label: "Date of Birth", value: "07/21/2003")
                Divider()
                labeledValue(label: "Gender", value: "Female")
            }
        }
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
            router.go(.ptDetail)
        case .journey:
            router.go(.journeyMap)
        case .settings:
            break
        }
    }

    private func handleAddTapped() {
        router.go(.pairDevice)
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

