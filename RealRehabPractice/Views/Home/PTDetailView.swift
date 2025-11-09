import SwiftUI
import Combine

struct PTDetailView: View {
    @EnvironmentObject var router: Router
    @StateObject private var vm = PatientPTViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RRSpace.section) {
                // PT Card
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                    .overlay(
                        VStack(alignment: .leading, spacing: 8) {
                            Text(vm.name.isEmpty ? "Your Physical Therapist" : vm.name)
                                .font(.rrTitle)
                                .foregroundStyle(.primary)
                            
                            Text("Phone: \(vm.phone.isEmpty ? "—" : vm.phone)")
                                .font(.rrBody)
                                .foregroundStyle(.secondary)
                            Text("Email: \(vm.email.isEmpty ? "—" : vm.email)")
                                .font(.rrBody)
                                .foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    )
                    .frame(minHeight: 110)
                    .padding(.horizontal, 16)
                    .padding(.top, RRSpace.pageTop)
                
                Rectangle()
                    .fill(Color.black.opacity(0.12))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
                
                // Current Rehab Plan section
                VStack(alignment: .leading, spacing: RRSpace.stack) {
                    Text("Current Rehab Plan")
                        .font(.rrTitle)
                        .padding(.horizontal, 16)
                    
                    // Gray landscape box - tappable → JourneyMapView
                    Button {
                        router.go(.journeyMap)
                    } label: {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.gray.opacity(0.15))
                            .frame(maxWidth: .infinity)
                            .frame(height: 190)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    
                    // ACL Rehab text below box
                    Text("ACL Rehab")
                        .font(.rrBody)
                        .foregroundStyle(.primary)
                        .padding(.top, 10)
                        .padding(.horizontal, 16)
                    
                    // Edit Schedule button
                    SecondaryButton(title: "Edit Schedule") {
                        router.go(.rehabOverview)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                }
                .padding(.top, 4)
                
                Spacer(minLength: 24)
            }
        }
        .rrPageBackground()
        .navigationTitle("Your Physical Therapist")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
        .task {
            await vm.load()
        }
    }
}

