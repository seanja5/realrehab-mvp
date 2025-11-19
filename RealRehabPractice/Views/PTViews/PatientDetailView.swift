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
    @State private var notesSaveTask: Task<Void, Never>? = nil
    
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
                            // Show image card - make it tappable
                            Button {
                                // Navigate to PTJourneyMapView with planId to edit existing plan
                                router.go(.ptJourneyMap(patientProfileId: patientProfileId, planId: plan.id))
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
                            
                            Text("\(plan.injury) Rehab")
                                .font(.rrBody)
                                .foregroundStyle(.primary)
                                .padding(.top, 10)
                                .padding(.horizontal, 16)
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
                    
                    // Progress this week section (outside the if/else to ensure consistent width)
                    if currentPlan != nil {
                        RecoveryChartWeekView()
                            .padding(.top, 16)
                        
                        // Activity section
                        ActivityConsistencyCard()
                            .padding(.top, 8)
                    }
                    
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
                    
                    // Access Code Section
                    if let accessCode = patient?.access_code, !accessCode.isEmpty {
                        VStack(alignment: .leading, spacing: RRSpace.stack) {
                            Text("Access Code")
                                .font(.rrTitle)
                            
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.white)
                                .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
                                .overlay(
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Share this code with your patient to link their account:")
                                            .font(.rrCaption)
                                            .foregroundStyle(.secondary)
                                        
                                        Text(accessCode)
                                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.primary)
                                            .frame(maxWidth: .infinity, alignment: .center)
                                            .padding(.vertical, 8)
                                    }
                                    .padding(16)
                                )
                                .frame(minHeight: 100)
                        }
                        .padding(.horizontal, 16)
                        
                        Rectangle()
                            .fill(Color.black.opacity(0.12))
                            .frame(height: 1)
                            .padding(.horizontal, 16)
                    }
                    
                    // Danger Zone
                    VStack(alignment: .leading, spacing: RRSpace.stack) {
                        Text("Remove")
                            .font(.rrTitle)
                            .foregroundStyle(.red)
                        
                        Button {
                            showDeleteConfirmation = true
                        } label: {
                            Text("Remove Patient")
                                .font(.rrBody)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.red, lineWidth: 1)
                                )
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
                    router.goWithoutAnimation(.patientList)
                case .settings:
                    router.goWithoutAnimation(.ptSettings)
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
            vm.setPTProfileId(session.ptProfileId)
            await loadPatientData(patientProfileId: patientProfileId)
        }
        .onChange(of: notes) { oldValue, newValue in
            // Auto-save notes after user stops typing (debounce)
            notesSaveTask?.cancel()
            notesSaveTask = Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                if !Task.isCancelled {
                    await saveNotes()
                }
            }
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
        .onDisappear {
            // Clear error message when navigating away to prevent showing cancelled errors
            errorMessage = nil
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
            let plan = try await RehabService.currentPlan(ptProfileId: ptProfileId, patientProfileId: patientProfileId)
            self.currentPlan = plan
            // Load notes from plan
            self.notes = plan?.notes ?? ""
        } catch {
            // Ignore cancellation errors when navigating quickly
            if error is CancellationError || Task.isCancelled {
                return
            }
            print("❌ PatientDetailView.loadPatientData error: \(error)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func saveNotes() async {
        guard let ptProfileId = session.ptProfileId else {
            print("❌ PatientDetailView.saveNotes: ptProfileId is nil")
            return
        }
        
        do {
            try await RehabService.updatePlanNotes(
                ptProfileId: ptProfileId,
                patientProfileId: patientProfileId,
                notes: notes.isEmpty ? nil : notes
            )
            print("✅ PatientDetailView: saved notes")
        } catch {
            // Ignore cancellation errors when navigating quickly
            if error is CancellationError || Task.isCancelled {
                return
            }
            print("❌ PatientDetailView.saveNotes error: \(error)")
            errorMessage = "Failed to save notes: \(error.localizedDescription)"
        }
    }
}

