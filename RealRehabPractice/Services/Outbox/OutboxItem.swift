//
//  OutboxItem.swift
//  RealRehabPractice
//
//  Persistent outbox item for offline-first sync. Payloads are JSON-encoded.
//

import Foundation

enum OutboxItemType: String, Codable {
    case lessonProgress
}

struct OutboxItem: Codable, Identifiable {
    let id: UUID
    let createdAt: Date
    let type: OutboxItemType
    let payload: Data
    var retryCount: Int
    var lastAttemptAt: Date?
}

// MARK: - Payloads

struct LessonProgressPayload: Codable {
    let patientProfileId: UUID
    let lessonId: UUID
    let repsCompleted: Int
    let repsTarget: Int
    let elapsedSeconds: Int
    let status: String
}
