import SwiftUI

struct PatientListView: View {
    @EnvironmentObject var router: Router
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                LazyVStack(spacing: 24) {
                    PatientCard(
                        name: "Andrews, Sean",
                        dob: "07/21/2003",
                        gender: "M",
                        onTap: { router.go(.ptPatientDetail) }
                    )
                    
                    PatientCard(name: "Smith, Jane", dob: "03/15/1995", gender: "F")
                    PatientCard(name: "Johnson, John", dob: "11/08/1988", gender: "M")
                    PatientCard(name: "Williams, Sarah", dob: "05/22/1992", gender: "F")
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 120)
            }
            
            PTTabBar(selected: .dashboard) { tab in
                switch tab {
                case .dashboard:
                    break
                case .settings:
                    router.go(.ptSettings)
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .rrPageBackground()
        .navigationTitle("Patients")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
    }
}

// MARK: - Patient Card
private struct PatientCard: View {
    let name: String
    let dob: String
    let gender: String
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.rrTitle)
                .foregroundStyle(.primary)
            
            Text("DOB: \(dob) • Gender: \(gender)")
                .font(.rrBody)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.white)
                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
}
