//
//  LocalLessonProgressStore.swift
//  RealRehabPractice
//
//  Persists lesson progress draft locally for offline resume. One file per lesson.
//

import Foundation

struct LocalLessonProgress: Codable {
    let lessonId: UUID
    var repsCompleted: Int
    var repsTarget: Int
    var elapsedSeconds: Int
    var updatedAt: Date
    var status: String
}

@MainActor
final class LocalLessonProgressStore {
    static let shared = LocalLessonProgressStore()

    private let fileManager = FileManager.default
    private var progressDirectory: URL {
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return caches.appendingPathComponent("RealRehabLessonProgress", isDirectory: true)
    }

    private init() {
        try? fileManager.createDirectory(at: progressDirectory, withIntermediateDirectories: true)
    }

    func saveDraft(lessonId: UUID, repsCompleted: Int, repsTarget: Int, elapsedSeconds: Int, status: String) {
        let draft = LocalLessonProgress(
            lessonId: lessonId,
            repsCompleted: repsCompleted,
            repsTarget: repsTarget,
            elapsedSeconds: elapsedSeconds,
            updatedAt: Date(),
            status: status
        )
        let fileURL = progressDirectory.appendingPathComponent("\(lessonId.uuidString).json")
        let tempURL = progressDirectory.appendingPathComponent("\(lessonId.uuidString).tmp.json")
        if let data = try? JSONEncoder().encode(draft) {
            try? data.write(to: tempURL)
            var resultURL: NSURL?
            try? fileManager.replaceItem(at: fileURL, withItemAt: tempURL, backupItemName: nil, options: [], resultingItemURL: &resultURL)
        }
    }

    func loadDraft(lessonId: UUID) -> LocalLessonProgress? {
        let fileURL = progressDirectory.appendingPathComponent("\(lessonId.uuidString).json")
        guard fileManager.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let draft = try? JSONDecoder().decode(LocalLessonProgress.self, from: data) else {
            return nil
        }
        return draft
    }

    func clearDraft(lessonId: UUID) {
        let fileURL = progressDirectory.appendingPathComponent("\(lessonId.uuidString).json")
        try? fileManager.removeItem(at: fileURL)
    }
}
