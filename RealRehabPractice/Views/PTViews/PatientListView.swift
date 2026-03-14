import SwiftUI

struct PatientListView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var session: SessionContext
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var vm = PTPatientsViewModel()
    
    private func formatPatientName(first: String, last: String) -> String {
        let firstTrimmed = first.trimmingCharacters(in: .whitespacesAndNewlines)
        let lastTrimmed = last.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if firstTrimmed.isEmpty && lastTrimmed.isEmpty {
            return "Unnamed Patient"
        } else if firstTrimmed.isEmpty {
            return lastTrimmed
        } else if lastTrimmed.isEmpty {
            return firstTrimmed
        } else {
            return "\(lastTrimmed), \(firstTrimmed)"
        }
    }
    
    private func formatDate(_ dateString: String?) -> String {
        guard let dateString = dateString else { return "—" }
        
        // Parse as local date to avoid timezone shifts
        if let date = Date.fromDateOnlyString(dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeZone = TimeZone.current
            return displayFormatter.string(from: date)
        }
        
        // If parsing fails, return as-is
        return dateString
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    OfflineStaleBanner(showBanner: !networkMonitor.isOnline && vm.showOfflineBanner)
                    VStack(spacing: 24) {
                    if vm.isLoading && vm.patients.isEmpty {
                        skeletonContent
                    } else if vm.patients.isEmpty {
                        EmptyState(
                            icon: "person.2",
                            title: "No patients yet",
                            description: "Add your first patient to get started.",
                            actionLabel: "Add Patient",
                            action: { vm.showAddOverlay = true }
                        )
                        .padding(.top, 60)
                    } else {
                        LazyVStack(spacing: 24) {
                            ForEach(vm.patients) { patient in
                                PatientCard(
                                    name: formatPatientName(first: patient.first_name, last: patient.last_name),
                                    dob: formatDate(patient.date_of_birth),
                                    gender: patient.gender?.capitalized ?? "—",
                                    email: patient.email,
                                    phone: patient.phone,
                                    accessCode: patient.access_code,
                                    patientProfileId: patient.patient_profile_id,
                                    isLinked: patient.profile_id != nil,
                                    onTap: {
                                        debugLog("📋 Opening patient \(patient.patient_profile_id.uuidString) with pt_profile_id=\(session.ptProfileId?.uuidString ?? "nil")")
                                        router.go(.ptPatientDetail(patientProfileId: patient.patient_profile_id))
                                    },
                                    onInvite: {
                                        guard let code = patient.access_code, !code.isEmpty else { return }
                                        ShareSheetHelper.presentShareSheet(code: code)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        
                        SecondaryButton(title: "Add Patient") {
                            vm.showAddOverlay = true
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 20)
                    }
                }
                .padding(.bottom, 120)
                }
            }
            
            PTTabBar(selected: .dashboard) { tab in
                switch tab {
                case .dashboard:
                    break
                case .settings:
                    router.goWithoutAnimation(.ptSettings)
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            
            // Add Patient Overlay
            if vm.showAddOverlay {
                addPatientOverlay
                    .zIndex(1)
            }
        }
        .rrPageBackground()
        .navigationTitle("My Patients")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .task {
            vm.setPTProfileId(session.ptProfileId)
            await vm.load(forceRefresh: false)
        }
        .onAppear {
            vm.setPTProfileId(session.ptProfileId)
        }
        .refreshable {
            await vm.load(forceRefresh: true)
        }
        .onChange(of: router.path.count) { oldCount, newCount in
            if newCount < oldCount { Task { await vm.load(forceRefresh: true) } }
        }
        .onChange(of: session.ptProfileId) { oldValue, newValue in
            vm.setPTProfileId(newValue)
        }
        .alert("Error", isPresented: .constant(vm.errorMessage != nil)) {
            Button("OK") {
                vm.errorMessage = nil
            }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .onDisappear {
            // Clear error message when navigating away to prevent showing cancelled errors
            vm.errorMessage = nil
        }
    }
    
    private var addPatientOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { withAnimation(RRAnimation.state) { vm.showAddOverlay = false } }

            VStack(spacing: 20) {
                Text("Add Patient")
                    .font(.rrTitle)
                    .foregroundStyle(.primary)

                FormTextField(title: "First Name", placeholder: "First Name", text: $vm.firstName)
                    .textContentType(.givenName)
                    .autocapitalization(.words)

                FormTextField(title: "Last Name", placeholder: "Last Name", text: $vm.lastName)
                    .textContentType(.familyName)
                    .autocapitalization(.words)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Date of Birth")
                        .font(.rrCaption)
                        .foregroundStyle(.secondary)

                    DatePicker("", selection: $vm.dateOfBirth, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                FormMenuField(title: "Gender", selection: $vm.gender, options: ["Male", "Female", "Non-binary", "Prefer not to say"])

                HStack(spacing: 12) {
                    SecondaryButton(title: "Cancel") {
                        withAnimation(RRAnimation.state) { vm.showAddOverlay = false }
                    }
                    .frame(maxWidth: .infinity)

                    PrimaryButton(
                        title: vm.isLoading ? "Adding..." : "Add",
                        isDisabled: vm.isLoading || vm.firstName.trimmingCharacters(in: .whitespaces).isEmpty || vm.lastName.trimmingCharacters(in: .whitespaces).isEmpty
                    ) {
                        Task { await vm.addPatient() }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(24)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.08), radius: 28, x: 0, y: 12)
                    .shadow(color: Color.brandDarkBlue.opacity(0.08), radius: 8, x: 0, y: 3)
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .transition(.opacity)
    }

    private var skeletonContent: some View {
        VStack(spacing: 24) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(white: 0.88))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 110)
                    .overlay(
                        VStack(alignment: .leading, spacing: 8) {
                            SkeletonBlock(width: 160, height: 18)
                            SkeletonBlock(width: 200, height: 14)
                            SkeletonBlock(width: 180, height: 14)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    )
                    .shimmer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }
}

// MARK: - Patient Card
private struct PatientCard: View {
    let name: String
    let dob: String
    let gender: String  // Already formatted (capitalized or "—")
    let email: String?
    let phone: String?
    var accessCode: String?
    var patientProfileId: UUID?
    var isLinked: Bool = false
    var onTap: (() -> Void)? = nil
    var onInvite: (() -> Void)? = nil
    
    /// Show Invite only when patient is not yet linked; button stays until patient successfully links.
    private var showInviteButton: Bool {
        guard !isLinked else { return false }
        guard let code = accessCode, !code.isEmpty, let _ = patientProfileId else { return false }
        return true
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(name)
                    .font(.rrTitle)
                    .foregroundStyle(.primary)
                
                Text("DOB: \(dob) • Gender: \(gender)")
                    .font(.rrBody)
                    .foregroundStyle(.secondary)
                
                if let email = email, !email.isEmpty {
                    Text("Email: \(email)")
                        .font(.rrBody)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Email: —")
                        .font(.rrBody)
                        .foregroundStyle(.secondary)
                }
                
                if let phone = phone, !phone.isEmpty {
                    Text("Phone: \(phone)")
                        .font(.rrBody)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Phone: —")
                        .font(.rrBody)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            
            if showInviteButton {
                Button(action: { onInvite?() }) {
                    Text("Invite")
                        .font(.rrCaption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [Color.brandDarkBlue, Color(red: 0.18, green: 0.36, blue: 0.78)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color.brandDarkBlue.opacity(0.30), radius: 6, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
                .padding(.trailing, 12)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.white)
                .shadow(color: .black.opacity(0.05), radius: 18, x: 0, y: 6)
                .shadow(color: Color.brandDarkBlue.opacity(0.07), radius: 6, x: 0, y: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }
}

