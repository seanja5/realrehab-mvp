import SwiftUI
import Combine

struct PTDetailView: View {
    @EnvironmentObject var router: Router
    @StateObject private var vm = PatientPTViewModel()
    @State private var scheduleSlots: [ScheduleService.ScheduleSlot] = []
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: RRSpace.section) {
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
                    
                    VStack(alignment: .leading, spacing: RRSpace.stack) {
                        Text("Current Rehab Plan")
                            .font(.rrTitle)
                            .padding(.horizontal, 16)
                        
                        if vm.hasRehabPlan {
                            Button {
                                router.go(.journeyMap)
                            } label: {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.gray.opacity(0.15))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 240)
                                    .overlay(
                                        Image("aclrehab")
                                            .resizable()
                                            .scaledToFill()
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                    )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                            
                            Text("ACL Rehab")
                                .font(.rrBody)
                                .foregroundStyle(.primary)
                                .padding(.top, 10)
                                .padding(.horizontal, 16)

                            Rectangle()
                                .fill(Color.black.opacity(0.12))
                                .frame(height: 1)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                            // My Schedule visualizer
                            ScheduleVisualizerView(slots: scheduleSlots)
                                .padding(.horizontal, 16)
                                .padding(.top, 8)

                            SecondaryButton(title: scheduleSlots.isEmpty ? "Create a Schedule" : "Edit Schedule") {
                                router.go(.rehabOverview)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            
                            // Progress this week section
                            RecoveryChartWeekView()
                                .padding(.top, 16)
                            
                            // Activity section - show 1 day for patient view
                            ActivityConsistencyCard(completedDays: 1)
                                .padding(.top, 8)
                        } else {
                            Text("No rehab plan assigned")
                                .font(.rrBody)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                    }
                    .padding(.top, 4)
                    
                    Spacer(minLength: 24)
                }
                .padding(.bottom, 120)
            }
            
            PatientTabBar(
                selected: .dashboard,
                onSelect: { tab in
                    switch tab {
                    case .dashboard:
                        break
                    case .journey:
                        router.goWithoutAnimation(.journeyMap)
                    case .settings:
                        router.goWithoutAnimation(.patientSettings)
                    }
                },
                onAddTapped: {
                    router.go(.pairDevice)
                }
            )
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .rrPageBackground()
        .navigationTitle("Your Physical Therapist")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                BluetoothStatusIndicator()
            }
        }
        .task {
            await vm.load()
            await loadSchedule()
        }
        .onAppear {
            Task { await loadSchedule() }
        }
        .bluetoothPopupOverlay()
    }

    private func loadSchedule() async {
        do {
            guard let profile = try await AuthService.myProfile() else { return }
            let patientProfileId = try await PatientService.myPatientProfileId(profileId: profile.id)
            let slots = try await ScheduleService.getSchedule(patientProfileId: patientProfileId)
            await MainActor.run {
                scheduleSlots = slots
            }
        } catch {
            scheduleSlots = []
        }
    }
}

