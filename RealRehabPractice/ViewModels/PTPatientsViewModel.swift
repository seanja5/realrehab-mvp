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
    
    private let genderOptions = ["Male", "Female", "Non-binary", "Prefer not to say"]
    
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            self.patients = try await PTService.listMyPatients()
        } catch {
            errorMessage = error.localizedDescription
            print("PTPatientsViewModel.load error: \(error)")
        }
        isLoading = false
    }
    
    func addPatient() async {
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
            errorMessage = error.localizedDescription
            print("PTPatientsViewModel.addPatient error: \(error)")
        }
        isLoading = false
    }
    
    func delete(patientProfileId: UUID) async {
        isLoading = true
        errorMessage = nil
        do {
            try await PTService.deletePatientMapping(patientProfileId: patientProfileId)
            await load()
        } catch {
            errorMessage = error.localizedDescription
            print("PTPatientsViewModel.delete error: \(error)")
        }
        isLoading = false
    }
}

