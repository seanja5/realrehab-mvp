import SwiftUI

struct RehabOverviewView: View {
    @EnvironmentObject var router: Router
    @State private var allowReminders = false
    @State private var allowCamera = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("ACL Rehab").font(.title2.bold())
                Text("Plan details, schedule, and preferences.")
                    .foregroundStyle(.secondary)
                Divider().padding(.vertical, 4)
                Toggle("Allow Reminders", isOn: $allowReminders)
                Toggle("Allow Camera", isOn: $allowCamera)
                Button("Confirm Journey!") { router.go(.journeyMap) }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle("Rehab Overview")
    }
}