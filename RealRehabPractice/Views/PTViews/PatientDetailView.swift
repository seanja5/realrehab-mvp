import SwiftUI

struct PatientDetailView: View {
    let patientProfileId: UUID
    @EnvironmentObject var router: Router
    @EnvironmentObject var session: SessionContext
    @StateObject private var vm = PTPatientsViewModel()
    @State private var notes: String = ""
    @State private var currentPlan: RehabService.PlanRow? = nil
    @State private var patient: PTService.SimplePatient? = nil
    @State private var isLoading = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String? = nil
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: RRSpace.section) {
                    Text(patientName)
                        .font(.rrHeadline)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, RRSpace.pageTop)
                    
                    Rectangle()
                        .fill(Color.black.opacity(0.12))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                    
                    Text(patientInfo)
                        .font(.rrBody)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 16)
                    
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.white)
                        .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                        .overlay(
                            HStack {
                                Text("Recent Appointments")
                                    .font(.rrTitle)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("11/4/25")
                                    .font(.rrBody)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(16)
                        )
                        .frame(minHeight: 110)
                        .padding(.horizontal, 16)
                    
                    Rectangle()
                        .fill(Color.black.opacity(0.12))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                    
                    VStack(alignment: .leading, spacing: RRSpace.stack) {
                        Text("Current Rehab Plan")
                            .font(.rrTitle)
                        
                        if let plan = currentPlan {
                            // Show gray card with plan info - make it tappable
                            Button {
                                // Navigate to PTJourneyMapView with planId to edit existing plan
                                router.go(.ptJourneyMap(patientProfileId: patientProfileId, planId: plan.id))
                            } label: {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 120)
                                    .overlay(
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("\(plan.category) - \(plan.injury)")
                                                .font(.rrTitle)
                                                .foregroundStyle(.primary)
                                        }
                                        .padding(16)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.bottom, 8)
                            
                            Text("\(plan.injury) Rehab")
                                .font(.rrBody)
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 8)
                            
                            SecondaryButton(title: "Change Rehab Plan") {
                                router.go(.ptCategorySelect(patientProfileId: patientProfileId))
                            }
                        } else {
                            SecondaryButton(title: "Select Rehab Plan") {
                                router.go(.ptCategorySelect(patientProfileId: patientProfileId))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    Rectangle()
                        .fill(Color.black.opacity(0.12))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                    
                    VStack(alignment: .leading, spacing: RRSpace.stack) {
                        Text("Notes")
                            .font(.rrTitle)
                        
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.white)
                            .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                            .overlay(
                                ZStack(alignment: .topLeading) {
                                    if notes.isEmpty {
                                        Text("Tap to add notes…")
                                            .font(.rrBody)
                                            .foregroundStyle(.secondary)
                                            .padding(16)
                                    }
                                    
                                    TextEditor(text: $notes)
                                        .font(.rrBody)
                                        .padding(12)
                                        .scrollContentBackground(.hidden)
                                        .background(Color.clear)
                                }
                            )
                            .frame(minHeight: 180)
                    }
                    .padding(.horizontal, 16)
                    
                    Rectangle()
                        .fill(Color.black.opacity(0.12))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                    
                    // Danger Zone
                    VStack(alignment: .leading, spacing: RRSpace.stack) {
                        Text("Danger Zone")
                            .font(.rrTitle)
                            .foregroundStyle(.red)
                        
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            Text("Delete Patient")
                                .font(.rrBody)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.red)
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    Spacer(minLength: 24)
                }
                .padding(.bottom, 120)
            }
            
            PTTabBar(selected: .dashboard) { tab in
                switch tab {
                case .dashboard:
                    router.go(.patientList)
                case .settings:
                    router.go(.ptSettings)
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .rrPageBackground()
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                BackButton()
            }
        }
        .task {
            await loadPatientData(patientProfileId: patientProfileId)
        }
        .alert("Delete Patient", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await vm.delete(patientProfileId: patientProfileId)
                    router.go(.patientList)
                }
            }
        } message: {
            Text("This will remove this patient from your list. This action cannot be undone.")
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private var patientName: String {
        if let patient = patient {
            return "\(patient.first_name) \(patient.last_name)"
        }
        return "Sean Andrews" // Placeholder
    }
    
    private var patientInfo: String {
        if let patient = patient {
            let dobString: String
            if let dateStr = patient.date_of_birth {
                // Parse ISO8601 date string (YYYY-MM-DD)
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withFullDate]
                if let date = isoFormatter.date(from: dateStr) {
                    dobString = dateFormatter.string(from: date)
                } else {
                    dobString = dateStr
                }
            } else {
                dobString = "—"
            }
            let genderStr = patient.gender?.capitalized ?? "—"
            return "DOB: \(dobString)   •   Gender: \(genderStr)"
        }
        return "DOB: 07/21/03   •   Gender: M" // Placeholder
    }
    
    private func loadPatientData(patientProfileId: UUID) async {
        guard let ptProfileId = session.ptProfileId else {
            errorMessage = "PT profile not available"
            print("❌ PatientDetailView.loadPatientData: ptProfileId is nil")
            return
        }
        
        isLoading = true
        do {
            // Load specific patient by patient_profile_id
            let loadedPatient = try await PTService.getPatient(patientProfileId: patientProfileId)
            self.patient = loadedPatient
            self.currentPlan = try await RehabService.currentPlan(ptProfileId: ptProfileId, patientProfileId: patientProfileId)
        } catch {
            print("❌ PatientDetailView.loadPatientData error: \(error)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

