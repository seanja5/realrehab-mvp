//
//  PatientStatus.swift
//  RealRehabPractice
//

import SwiftUI

enum PatientStatus: Equatable {
    case onTrack
    case fallingBehind
    case needsHelp
    case neutral

    var label: String {
        switch self {
        case .onTrack:       return "On Track"
        case .fallingBehind: return "Falling Behind"
        case .needsHelp:     return "Needs Help"
        case .neutral:       return "My Patient"
        }
    }

    var color: Color {
        switch self {
        case .onTrack:       return Color(red: 0.13, green: 0.67, blue: 0.31)
        case .fallingBehind: return Color(red: 0.90, green: 0.65, blue: 0.10)
        case .needsHelp:     return Color(red: 0.85, green: 0.20, blue: 0.20)
        case .neutral:       return .clear
        }
    }

    /// Derives status from sorted-descending completion dates (RehabService.getCompletionDates).
    /// Returns .neutral when no lessons have been completed.
    static func compute(from completionDates: [Date]) -> PatientStatus {
        guard !completionDates.isEmpty, let last = completionDates.first else { return .neutral }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let lastDay = cal.startOfDay(for: last)
        let days = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0
        if days < 3 { return .onTrack }
        if days < 5 { return .fallingBehind }
        return .needsHelp
    }
}
