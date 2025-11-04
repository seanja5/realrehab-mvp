import SwiftUI

struct PatientListView: View {
    @EnvironmentObject var router: Router
    
    private let patients: [(name: String, dob: String, gender: String, tappable: Bool)] = [
        (name: "Andrews, Sean", dob: "07/21/2003", gender: "M", tappable: true),
        (name: "Smith, Jane", dob: "03/15/1995", gender: "F", tappable: false),
        (name: "Johnson, John", dob: "11/08/1988", gender: "M", tappable: false),
        (name: "Williams, Sarah", dob: "05/22/1992", gender: "F", tappable: false)
    ]
    
    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 16) {
                ForEach(Array(patients.enumerated()), id: \.offset) { index, patient in
                    PatientCard(
                        name: patient.name,
                        dob: patient.dob,
                        gender: patient.gender,
                        tappable: patient.tappable
                    ) {
                        if patient.tappable {
                            router.go(.ptCategorySelect)
                        }
                    }
                }
            }
            .padding(.top, RRSpace.pageTop)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
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
struct PatientCard: View {
    let name: String
    let dob: String
    let gender: String
    let tappable: Bool
    var action: (() -> Void)?
    
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color.white)
            .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
            .overlay(
                VStack(alignment: .leading, spacing: 6) {
                    Text(name)
                        .font(.rrTitle)
                    Text("DOB: \(dob) • Gender: \(gender)")
                        .font(.rrBody)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if tappable {
                    action?()
                }
            }
            .opacity(tappable ? 1.0 : 0.6)
    }
}

