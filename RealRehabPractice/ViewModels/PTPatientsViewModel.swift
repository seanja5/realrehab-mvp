import Foundation
import Combine

@MainActor
final class PTPatientsViewModel: ObservableObject {
    @Published var patients: [PTService.SimplePatient] = []
    @Published var showAddOverlay = false
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var dateOfBirth = Date()
    @Published var gender = "Male"
    @Published var isLoading = false
    @Published var errorMessage: String?
    /// True when we should show the offline/stale banner (offline and either data is stale or user tried to refresh).
    @Published var showOfflineBanner = false
    
    private let genderOptions = ["Male", "Female", "Non-binary", "Prefer not to say"]
    private var ptProfileId: UUID?
    
    func setPTProfileId(_ id: UUID?) {
        self.ptProfileId = id
    }
    
    func load(forceRefresh: Bool = false) async {
        guard let ptProfileId = ptProfileId else {
            errorMessage = "PT profile not available"
            print("❌ PTPatientsViewModel.load: ptProfileId is nil")
            return
        }
        
        isLoading = true
        errorMessage = nil
        showOfflineBanner = false
        do {
            let (list, isStale) = try await PTService.listMyPatientsForDisplay(ptProfileId: ptProfileId)
            self.patients = list
            self.showOfflineBanner = !NetworkMonitor.shared.isOnline && (isStale || forceRefresh)
            print("✅ PTPatientsViewModel.load: loaded \(self.patients.count) patients for pt_profile_id=\(ptProfileId.uuidString)")
        } catch {
            if error is CancellationError || Task.isCancelled {
                return
            }
            if patients.isEmpty {
                errorMessage = error.localizedDescription
                print("❌ PTPatientsViewModel.load error: \(error)")
            }
        }
        isLoading = false
    }
    
    func addPatient() async {
        guard let ptProfileId = ptProfileId else {
            errorMessage = "PT profile not available"
            return
        }
        
        guard !firstName.trimmingCharacters(in: .whitespaces).isEmpty,
              !lastName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "First name and last name are required"
            return
        }
        
        isLoading = true
        errorMessage = nil
        do {
            let apiGender = GenderMapper.apiValue(from: gender)
            try await PTService.addPatient(
                ptProfileId: ptProfileId,
                firstName: firstName.trimmingCharacters(in: .whitespaces),
                lastName: lastName.trimmingCharacters(in: .whitespaces),
                dob: dateOfBirth,
                gender: apiGender
            )
            // Reset form
            firstName = ""
            lastName = ""
            dateOfBirth = Date()
            gender = "Male"
            showAddOverlay = false
            // Reload list
            await load()
        } catch {
            // Ignore cancellation errors when navigating quickly
            if error is CancellationError || Task.isCancelled {
                return
            }
            errorMessage = error.localizedDescription
            print("❌ PTPatientsViewModel.addPatient error: \(error)")
        }
        isLoading = false
    }
    
    func delete(patientProfileId: UUID) async {
        guard let ptProfileId = ptProfileId else {
            errorMessage = "PT profile not available"
            return
        }
        
        isLoading = true
        errorMessage = nil
        do {
            try await PTService.deletePatientMapping(ptProfileId: ptProfileId, patientProfileId: patientProfileId)
            await load()
        } catch {
            // Ignore cancellation errors when navigating quickly
            if error is CancellationError || Task.isCancelled {
                return
            }
            errorMessage = error.localizedDescription
            print("❌ PTPatientsViewModel.delete error: \(error)")
        }
        isLoading = false
    }
}

