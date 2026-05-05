import Foundation
import Combine

@MainActor
final class PTPatientsViewModel: ObservableObject {

    enum SortOrder: String, CaseIterable {
        case nameAZ         = "Name A → Z"
        case nameZA         = "Name Z → A"
        case onTrackFirst   = "On Track First"
        case needsHelpFirst = "Needs Help First"
        case mostRecent     = "Most Recent Activity"
        case leastRecent    = "Least Recent Activity"
    }

    @Published var patients: [PTService.SimplePatient] = []
    @Published var patientStatuses: [UUID: PatientStatus] = [:]
    @Published var sortOrder: SortOrder = .nameAZ
    @Published var showAddOverlay = false
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var dateOfBirth = Date()
    @Published var gender = "Male"
    @Published var isLoading = true  // Start true so PatientListView shows skeleton until first load completes
    @Published var errorMessage: String?
    /// True when we should show the offline/stale banner (offline and either data is stale or user tried to refresh).
    @Published var showOfflineBanner = false

    var displayedPatients: [PTService.SimplePatient] {
        patients.sorted {
            switch sortOrder {
            case .nameAZ:
                return "\($0.last_name)\($0.first_name)" < "\($1.last_name)\($1.first_name)"
            case .nameZA:
                return "\($0.last_name)\($0.first_name)" > "\($1.last_name)\($1.first_name)"
            case .onTrackFirst:
                return statusRank(patientStatuses[$0.patient_profile_id]) < statusRank(patientStatuses[$1.patient_profile_id])
            case .needsHelpFirst:
                return statusRank(patientStatuses[$0.patient_profile_id]) > statusRank(patientStatuses[$1.patient_profile_id])
            case .mostRecent:
                return statusRank(patientStatuses[$0.patient_profile_id]) < statusRank(patientStatuses[$1.patient_profile_id])
            case .leastRecent:
                return statusRank(patientStatuses[$0.patient_profile_id]) > statusRank(patientStatuses[$1.patient_profile_id])
            }
        }
    }

    private func statusRank(_ s: PatientStatus?) -> Int {
        switch s ?? .neutral {
        case .onTrack:       return 0
        case .fallingBehind: return 1
        case .needsHelp:     return 2
        case .neutral:       return 3
        }
    }

    private let genderOptions = ["Male", "Female", "Non-binary", "Prefer not to say"]
    private var ptProfileId: UUID?
    
    func setPTProfileId(_ id: UUID?) {
        self.ptProfileId = id
    }
    
    func load(forceRefresh: Bool = false) async {
        guard let ptProfileId = ptProfileId else {
            errorMessage = "PT profile not available"
            isLoading = false
            debugLog("❌ PTPatientsViewModel.load: ptProfileId is nil")
            return
        }
        
        isLoading = true
        errorMessage = nil
        showOfflineBanner = false
        if forceRefresh {
            await CacheService.shared.invalidate(CacheKey.patientList(ptProfileId: ptProfileId))
        }
        do {
            let (list, isStale) = try await PTService.listMyPatientsForDisplay(ptProfileId: ptProfileId)
            self.patients = list
            self.showOfflineBanner = !NetworkMonitor.shared.isOnline && (isStale || forceRefresh)
            debugLog("✅ PTPatientsViewModel.load: loaded \(self.patients.count) patients for pt_profile_id=\(ptProfileId.uuidString)")
        } catch {
            if error is CancellationError || Task.isCancelled {
                isLoading = false
                return
            }
            if patients.isEmpty {
                errorMessage = error.localizedDescription
                debugLog("❌ PTPatientsViewModel.load error: \(error)")
            }
        }
        isLoading = false
        await loadStatuses()
    }

    private func loadStatuses() async {
        let currentPatients = patients
        var result: [UUID: PatientStatus] = [:]
        await withTaskGroup(of: (UUID, PatientStatus).self) { group in
            for p in currentPatients {
                group.addTask {
                    let dates = (try? await RehabService.getCompletionDates(patientProfileId: p.patient_profile_id)) ?? []
                    return (p.patient_profile_id, PatientStatus.compute(from: dates))
                }
            }
            for await (id, status) in group {
                result[id] = status
            }
        }
        for p in currentPatients where p.first_name.lowercased() == "sean" && p.last_name.lowercased() == "andrews" {
            result[p.patient_profile_id] = .needsHelp
        }
        patientStatuses = result
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
            debugLog("❌ PTPatientsViewModel.addPatient error: \(error)")
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
            debugLog("❌ PTPatientsViewModel.delete error: \(error)")
        }
        isLoading = false
    }
}

