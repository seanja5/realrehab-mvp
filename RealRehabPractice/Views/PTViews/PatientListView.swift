import SwiftUI

struct PatientListView: View {
    @EnvironmentObject var router: Router
    @EnvironmentObject var session: SessionContext
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
        
        // Parse ISO8601 date string (YYYY-MM-DD)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        
        if let date = isoFormatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            return displayFormatter.string(from: date)
        }
        
        // If parsing fails, return as-is
        return dateString
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 24) {
                    if vm.patients.isEmpty {
                        VStack(spacing: 20) {
                            Spacer()
                                .frame(height: 100)
                            
                            Text("You don't have any patients added yet")
                                .font(.rrBody)
                                .foregroundStyle(.secondary)
                            
                            SecondaryButton(title: "Add Patient") {
                                vm.showAddOverlay = true
                            }
                            .padding(.horizontal, 24)
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        LazyVStack(spacing: 24) {
                            ForEach(vm.patients) { patient in
                                PatientCard(
                                    name: formatPatientName(first: patient.first_name, last: patient.last_name),
                                    dob: formatDate(patient.date_of_birth),
                                    gender: patient.gender?.capitalized ?? "—",
                                    email: patient.email,
                                    phone: patient.phone,
                                    onTap: {
                                        print("📋 Opening patient \(patient.patient_profile_id.uuidString) with pt_profile_id=\(session.ptProfileId?.uuidString ?? "nil")")
                                        router.go(.ptPatientDetail(patientProfileId: patient.patient_profile_id))
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
            }
        }
        .rrPageBackground()
        .navigationTitle("Patients")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .task {
            vm.setPTProfileId(session.ptProfileId)
            await vm.load()
        }
        .onChange(of: session.ptProfileId) { newValue in
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
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .onTapGesture {
                vm.showAddOverlay = false
            }
            .overlay {
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
                            vm.showAddOverlay = false
                        }
                        .frame(maxWidth: .infinity)
                        
                        PrimaryButton(
                            title: vm.isLoading ? "Adding..." : "Add",
                            isDisabled: vm.isLoading || vm.firstName.trimmingCharacters(in: .whitespaces).isEmpty || vm.lastName.trimmingCharacters(in: .whitespaces).isEmpty
                        ) {
                            Task {
                                await vm.addPatient()
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(24)
                .frame(maxWidth: 340)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
                )
            }
    }
}

// MARK: - Patient Card
private struct PatientCard: View {
    let name: String
    let dob: String
    let gender: String  // Already formatted (capitalized or "—")
    let email: String?
    let phone: String?
    var onTap: (() -> Void)? = nil
    
    var body: some View {
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

// MARK: - Form Field Helpers
private func FormTextField(title: String, placeholder: String, text: Binding<String>) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(.rrCaption)
            .foregroundStyle(.secondary)
        
        TextField(placeholder, text: text)
            .font(.rrBody)
            .padding(14)
            .background(Color(uiColor: .secondarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private func FormMenuField(title: String, selection: Binding<String>, options: [String]) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        Text(title)
            .font(.rrCaption)
            .foregroundStyle(.secondary)
        
        Menu {
            ForEach(options, id: \.self) { option in
                Button(option) {
                    selection.wrappedValue = option
                }
            }
        } label: {
            HStack {
                Text(selection.wrappedValue.isEmpty ? "Select" : selection.wrappedValue)
                    .font(.rrBody)
                    .foregroundStyle(selection.wrappedValue.isEmpty ? Color.secondary : Color.primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.rrCaption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}
