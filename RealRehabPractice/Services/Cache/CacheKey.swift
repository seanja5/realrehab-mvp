import Foundation

/// Cache key utilities for consistent key generation
enum CacheKey {
    // Patient profile keys
    static func patientProfile(userId: UUID) -> String {
        "patient_profile:\(userId.uuidString)"
    }
    
    static func patientEmail(profileId: UUID) -> String {
        "patient_email:\(profileId.uuidString)"
    }
    
    static func hasPT(patientProfileId: UUID) -> String {
        "has_pt:\(patientProfileId.uuidString)"
    }
    
    // PT profile keys
    static func ptProfile(profileId: UUID) -> String {
        "pt_profile:\(profileId.uuidString)"
    }
    
    // PT info for patient view
    static func ptInfo(patientProfileId: UUID) -> String {
        "pt_info:\(patientProfileId.uuidString)"
    }
    
    // PT profile ID from patient profile ID
    static func ptProfileIdFromPatient(patientProfileId: UUID) -> String {
        "pt_profile_id:\(patientProfileId.uuidString)"
    }
    
    // Rehab plan keys
    static func rehabPlan(ptProfileId: UUID, patientProfileId: UUID) -> String {
        "rehab_plan:\(ptProfileId.uuidString):\(patientProfileId.uuidString)"
    }
    
    // Patient list key (PT role)
    static func patientList(ptProfileId: UUID) -> String {
        "patient_list:\(ptProfileId.uuidString)"
    }
    
    // Patient detail key (PT role)
    static func patientDetail(patientProfileId: UUID) -> String {
        "patient_detail:\(patientProfileId.uuidString)"
    }
    
    // Assignment key
    static func activeAssignment(userId: UUID) -> String {
        "active_assignment:\(userId.uuidString)"
    }
    
    // Program key
    static func program(programId: UUID) -> String {
        "program:\(programId.uuidString)"
    }
    
    // Lessons key
    static func lessons(programId: UUID) -> String {
        "lessons:\(programId.uuidString)"
    }
    
    // Auth profile key
    static func authProfile(userId: UUID) -> String {
        "auth_profile:\(userId.uuidString)"
    }
    
    // Patient profile ID key
    static func patientProfileId(profileId: UUID) -> String {
        "patient_profile_id:\(profileId.uuidString)"
    }
}

