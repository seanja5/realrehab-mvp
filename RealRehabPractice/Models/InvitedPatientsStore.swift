//
//  InvitedPatientsStore.swift
//  RealRehabPractice
//
//  Tracks which patients the PT has used "Invite" (share sheet) for, so we can hide the Invite button on the card after first use.
//

import SwiftUI
import Combine

private let userDefaultsKey = "RealRehab.invitedPatientIds"

@MainActor
final class InvitedPatientsStore: ObservableObject {
    @Published private var invitedIds: Set<UUID> = InvitedPatientsStore.loadStored()
    
    func hasInvited(_ patientProfileId: UUID) -> Bool {
        invitedIds.contains(patientProfileId)
    }
    
    func markInvited(_ patientProfileId: UUID) {
        invitedIds.insert(patientProfileId)
        save()
    }
    
    private static func loadStored() -> Set<UUID> {
        guard let raw = UserDefaults.standard.array(forKey: userDefaultsKey) as? [String] else { return [] }
        return Set(raw.compactMap { UUID(uuidString: $0) })
    }
    
    private func save() {
        let raw = invitedIds.map { $0.uuidString }
        UserDefaults.standard.set(raw, forKey: userDefaultsKey)
    }
}
