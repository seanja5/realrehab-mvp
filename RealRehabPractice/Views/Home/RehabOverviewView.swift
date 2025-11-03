import SwiftUI

struct RehabOverviewView: View {
    @EnvironmentObject var router: Router
    @State private var allowReminders = false
    @State private var allowCamera = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RRSpace.section) {
                Text("ACL Rehab")
                    .font(.rrHeadline)
                Text("Plan details, schedule, and preferences.")
                    .font(.rrCallout)
                    .foregroundStyle(.secondary)
                Divider()
                    .padding(.vertical, 4)
                Toggle("Allow Reminders", isOn: $allowReminders)
                    .font(.rrBody)
                Toggle("Allow Camera", isOn: $allowCamera)
                    .font(.rrBody)
                Spacer()
                    .frame(minHeight: 40)
                PrimaryButton(title: "Confirm Journey!") {
                    router.go(.journeyMap)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .rrPageBackground()
        .navigationTitle("Rehab Overview")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
    }
}